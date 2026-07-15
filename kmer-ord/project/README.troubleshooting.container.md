# Nextflow / Apptainer Custom Container Troubleshooting Notes
**Date:** 2026-07-15

## Issue Summary

A custom `kmer-ord` container worked perfectly when run interactively, but failed when executed by Nextflow.

### Manual execution inside the container

Running interactively with:

```bash
apptainer shell kmer-ord.linux.amd64.potentiallyWorking.needsTesting.20260629.sif
```

followed by

```bash
kmer-ord project ...
```

worked successfully.

---

## Initial Symptom

When executed by Nextflow, the pipeline consistently failed during the UMAP import with:

```text
RuntimeError: cannot cache function 'rdist':
no locator available for file
'/opt/conda/lib/python3.11/site-packages/umap/layouts.py'
```

The traceback occurred before any dimensionality reduction actually started, indicating the failure happened during Python module import.

---

# Investigation

## Verified the container itself was not broken

Inside the container:

```bash
python - <<EOF
import umap, numba
print(umap.__file__)
print(numba.__version__)
EOF
```

returned

```
/opt/conda/lib/python3.11/site-packages/umap/__init__.py
0.65.1
```

Running the exact same `kmer-ord project` command manually also completed successfully.

This ruled out:

- kmer-ord
- UMAP
- the container image
- the input data

---

## Compared Nextflow vs manual execution

Eventually the problem was isolated to the way Nextflow launches containers.

Nextflow launches containers similarly to:

```bash
singularity exec \
    --no-home \
    --pid \
    -B /ibex/project/... \
    image.sif \
    command
```

Running a minimal import test reproduced the problem immediately.

### Failing

```bash
singularity exec \
  --no-home \
  --pid \
  -B /ibex/project/c2303/20260715_NF-KMER-ORD \
  kmer-ord.linux.amd64.potentiallyWorking.needsTesting.20260629.sif \
  python -c "import umap; print('OK')"
```

Result:

```
RuntimeError:
cannot cache function 'rdist':
no locator available for file
'/opt/conda/lib/python3.11/site-packages/umap/layouts.py'
```

---

### Working

Removing **only** `--no-home`:

```bash
singularity exec \
  --pid \
  -B /ibex/project/c2303/20260715_NF-KMER-ORD \
  kmer-ord.linux.amd64.potentiallyWorking.needsTesting.20260629.sif \
  python -c "import umap; print('OK')"
```

Result:

```
OK
```

This proved the issue had nothing to do with Nextflow itself.

The trigger was specifically:

```
--no-home
```

---

# Root Cause

`umap-learn` imports several functions decorated with

```python
@numba.njit(cache=True)
```

during module import.

When the container is launched with

```
--no-home
```

Numba 0.65.1 fails while creating its cache locator and throws

```
RuntimeError:
cannot cache function 'rdist':
no locator available
```

The failure occurs **before any kmer-ord code executes**.

---

# Solution

Instead of relying on the (missing) home directory created by `--no-home`, explicitly define one inside the Nextflow process.

At the top of the process script:

```bash
export HOME=$PWD
```

Final process script:

```groovy
script:
def args = task.ext.args ?: ""
def prefix = task.ext.prefix ?: "${meta.id}"

"""
export HOME=\$PWD

mkdir -p ${prefix}_kmerord_project

kmer-ord project \\
    --input ${input} \\
    --output ${prefix}_kmerord_project \\
    --threads ${task.cpus} \\
    ${args}

cat <<-END_VERSIONS > versions.yml
"${task.process}":
    kmer-ord: \$(kmer-ord --version 2>&1 | sed 's/^v//')
END_VERSIONS
"""
```

After adding

```bash
export HOME=$PWD
```

the process executed successfully under Nextflow.

---

# Lessons Learned

When a container works interactively but fails under Nextflow:

1. Verify the exact container works manually.
2. Reproduce the failure with a minimal command (e.g. `python -c "import package"`).
3. Compare the `singularity exec` flags used by Nextflow.
4. Remove flags one at a time until the failure disappears.
5. If `--no-home` is involved, test by setting:

```bash
export HOME=$PWD
```

before running the program.

---

# Useful Debug Commands

Check whether a package imports:

```bash
python -c "import umap; print('OK')"
```

Check installation:

```bash
python - <<EOF
import umap, numba
print(umap.__file__)
print(numba.__version__)
EOF
```

Check filesystem visibility:

```bash
python - <<EOF
import os

f="/opt/conda/lib/python3.11/site-packages/umap/layouts.py"

print(os.path.exists(f))
print(os.path.isfile(f))
print(os.path.realpath(f))
print(os.access(f, os.R_OK))
EOF
```

Compare execution modes:

Works:

```bash
apptainer shell image.sif
```

Works:

```bash
singularity exec --pid image.sif ...
```

Fails:

```bash
singularity exec --no-home --pid image.sif ...
```

---

# Key Takeaway

If a custom Apptainer/Singularity container fails only under Nextflow with a Numba caching error during import (especially involving `umap`), first check whether Nextflow is launching the container with `--no-home`.

A simple

```bash
export HOME=\$PWD
```

inside the Nextflow process can restore a valid writable home directory and resolve the issue without modifying the container.

e.g.

```groovy
  script:
  def args = task.ext.args ?: ""
  def prefix = task.ext.prefix ?: "${meta.id}"

  """
    export HOME=\$PWD

    mkdir -p ${prefix}_kmerord_project

    kmer-ord project \\
        --input ${input} \\
        --output ${prefix}_kmerord_project \\
        --threads ${task.cpus} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kmer-ord: \$(kmer-ord --version 2>&1 | sed 's/^v//')
    END_VERSIONS
    """
```