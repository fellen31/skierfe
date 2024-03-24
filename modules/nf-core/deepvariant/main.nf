process DEEPVARIANT {
    tag "$meta.id"
    label 'process_high'

    //Conda is not supported at the moment
    container "nf-core/deepvariant:1.5.0"

    input:
    tuple val(meta), path(input), path(index), path(intervals)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fai)
    tuple val(meta4), path(gzi)

    output:
    tuple val(meta), path("*.deepvariant.vcf.gz")    , emit: vcf
    tuple val(meta), path("*.deepvariant.vcf.gz.tbi"), emit: vcf_tbi
    tuple val(meta), path("*.g.vcf.gz")              , emit: gvcf
    tuple val(meta), path("*.g.vcf.gz.tbi")          , emit: gvcf_tbi
    path("*"),emit: all
    path "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "DEEPVARIANT module does not support Conda. Please use Docker / Singularity / Podman instead."
    }
    def args = task.ext.args ?: ''
    //prefix = task.ext.prefix ?: "${meta.id}"
    def regions = intervals ? "--regions=${intervals}" : ""
    def output_name = intervals ? "${meta.id}" + "." + "${intervals.getSimpleName()}" : "${meta.id}"
    """
    /opt/deepvariant/bin/run_deepvariant \\
        --ref=${fasta} \\
        --reads=${input} \\
        --output_vcf=${output_name}.deepvariant.vcf.gz \\
        --output_gvcf=${output_name}.g.vcf.gz \\
        ${args} \\
        ${regions} \\
        --intermediate_results_dir=. \\
        --num_shards=${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        deepvariant: \$(echo \$(/opt/deepvariant/bin/run_deepvariant --version) | sed 's/^.*version //; s/ .*\$//' )
    END_VERSIONS
    """

    stub:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "DEEPVARIANT module does not support Conda. Please use Docker / Singularity / Podman instead."
    }
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.vcf.gz
    touch ${prefix}.vcf.gz.tbi
    touch ${prefix}.g.vcf.gz
    touch ${prefix}.g.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        deepvariant: \$(echo \$(/opt/deepvariant/bin/run_deepvariant --version) | sed 's/^.*version //; s/ .*\$//' )
    END_VERSIONS
    """
}
