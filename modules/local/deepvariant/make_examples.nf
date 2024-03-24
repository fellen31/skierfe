process DEEPVARIANT {
    tag "$meta.id"
    label 'process_low'

    //Conda is not supported at the moment
    container "nf-core/deepvariant:1.5.0"

    input:
    tuple val(meta), path(input), path(index), path(intervals), val(tasks)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fai)
    tuple val(meta4), path(gzi)
    val(end)

    output:
    tuple val(meta), path("make_examples*.gz"), emit: examples
    tuple val(meta), path("gvcf*.gz"), emit: gvcf
    path "versions.yml"       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "DEEPVARIANT module does not support Conda. Please use Docker / Singularity / Podman instead."
    }
    def args = task.ext.args ?: ''
    //prefix = task.ext.prefix ?: "${meta.id}"
    def regions = intervals ? '--regions' + '=' + "$intervals" : ""
    def output_name = intervals ? "${meta.id}" + "." + "${intervals.getSimpleName()}" : "${meta.id}"

    def n_tasks = tasks.join(' ')
    """
    parallel -j ${task.cpus} --halt 2 --line-buffer eval /opt/deepvariant/bin/make_examples \\
        --mode calling \\
        --ref ${fasta} \\
        --reads ${input} \\
        --examples ./make_examples.tfrecord@${end}.gz \\
        --add_hp_channel \\
        --alt_aligned_pileup diff_channels \\
        --gvcf ./gvcf.tfrecord@${end}.gz \\
        --max_reads_per_partition "600" \\
        --min_mapping_quality 1 \\
        --parse_sam_aux_fields \\
        --partition_size 25000 \\
        --phase_reads \\
        --pileup_image_width 199 \\
        --norealign_reads \\
        --sample_name ${meta.id} \\
        --sort_by_haplotypes \\
        --track_ref_reads \\
        --vsc_min_fraction_indels 0.12 ${regions} --task {} ::: ${n_tasks}

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
