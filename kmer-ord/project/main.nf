process KMER_ORD_PROJECT {

  tag "${meta.id}"
  label 'process_medium'
  label 'process_gpu'

  conda "${moduleDir}/environment.yml"
  container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
    ? '/ibex/project/c2303/20260614_make-kmer-ord-singularity-container/kmer-ord.linux.amd64.potentiallyWorking.needsTesting.20260629.sif'
    : 'docker://PLACEHOLDER_DOCKER_IMAGE'}"

  input:
  tuple val(meta), path(input)

  output:
  tuple val(meta), path("results"), emit: results_dir
  path "versions.yml", emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def args = task.ext.args ?: ""
  def prefix = task.ext.prefix ?: "${meta.id}"
  def kmer_size = task.ext.kmer_size ?: 6

  """
    export HOME=\$PWD

    mkdir -p results

    kmer-ord project \\
        --input ${input} \\
        --output results \\
        --threads ${task.cpus} \\
        --kmer-size ${kmer_size} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kmer-ord: aa22b130903e8f6aa71c881b22c4b18b2efd2486
    END_VERSIONS
    """

  stub:
  def prefix = task.ext.prefix ?: "${meta.id}"

  """
    mkdir -p results

    touch results/stub.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kmer-ord: stub
    END_VERSIONS
    """
}
