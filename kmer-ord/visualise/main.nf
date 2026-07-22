process KMER_ORD_VISUALISE {

  tag "${meta.id}"
  label 'process_medium'

  conda "${moduleDir}/environment.yml"
  container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
    ? '/ibex/project/c2303/20260614_make-kmer-ord-singularity-container/kmer-ord.linux.amd64.potentiallyWorking.needsTesting.20260719.sif'
    : 'docker://PLACEHOLDER_DOCKER_IMAGE'}"

  input:
  tuple val(meta), path(db)

  output:
  tuple val(meta), path("results"), emit: results_dir
  path "versions.yml", emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def args = task.ext.args ?: ""

  def sample_args = [
      meta.max_categories != null ? "--max-categories ${meta.max_categories}" : null,
      meta.embeddings != null && !meta.embeddings ? "--no-embeddings" : "--embeddings",
      meta.embedding_mode ? "--embedding-mode ${meta.embedding_mode}" : null,
      meta.features != null && !meta.features ? "--no-features" : "--features"
  ].findAll { argument -> argument }.join(" ")

  """
    export HOME=\$PWD

    mkdir -p results

    kmer-ord visualise \\
        --db ${db} \\
        ${sample_args} \\
        --output results \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kmer-ord: aa22b130903e8f6aa71c881b22c4b18b2efd2486
    END_VERSIONS
    """

  stub:
  """
    mkdir -p results

    touch results/stub.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kmer-ord: stub
    END_VERSIONS
    """
}