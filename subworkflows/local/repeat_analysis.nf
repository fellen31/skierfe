include { TRGT } from '../../subworkflows/local/trgt.nf'

workflow REPEAT_ANALYSIS {

    take:
    ch_bam_bai
    ch_fasta
    ch_fai
    ch_trgt_bed

    main:
    ch_versions = Channel.empty()

    TRGT (
         ch_bam_bai,
         ch_fasta,
         ch_fai,
         ch_trgt_bed
    )
    ch_versions = ch_versions.mix(TRGT.out.versions)

    emit:
    versions = ch_versions // channel: [ versions.yml ]
}

