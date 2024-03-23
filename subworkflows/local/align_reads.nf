include { MINIMAP2_INDEX                                  } from '../../modules/nf-core/minimap2/index/main'
include { FASTP                                           } from '../../modules/nf-core/fastp/main'
include { MINIMAP2_ALIGN as MINIMAP2_ALIGN_UNSPLIT        } from '../../modules/nf-core/minimap2/align/main'
include { MINIMAP2_ALIGN as MINIMAP2_ALIGN_SPLIT          } from '../../modules/nf-core/minimap2/align/main'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_MINIMAP2_ALIGN } from '../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_SORT                                   } from '../../modules/nf-core/samtools/sort/main'

workflow ALIGN_READS {

    // Maybe it's possible to do the preprocessing in a separate workflow,
    // then specify in meta if the read that should be aligned is split or not
    // for a cleaner workflow? - branch channel on meta."split"?

    take:
    ch_sample // channel: [ val(meta), fastq ]
    ch_fasta  // channel: [ val(meta), fasta ]

    main:
    ch_versions = Channel.empty()
    ch_bam      = Channel.empty()
    ch_csi      = Channel.empty()
    ch_bam_csi  = Channel.empty()

    MINIMAP2_INDEX ( ch_fasta )
    ch_versions = ch_versions.mix(MINIMAP2_INDEX.out.versions)

    // Remap index
    MINIMAP2_INDEX.out.index
        .set { ch_index }

    // Split FASTQ
    if (params.split_fastq >= 250) {

        // Add meta info for fastp
        ch_sample
            .map { meta, fastq -> [ meta + [ 'single_end': true ], fastq ] }
            .set { ch_fastp_in }

        // To run this params.split_fastq must be >= 250
        FASTP ( ch_fastp_in, [], [], [] )
        ch_versions = ch_versions.mix(FASTP.out.versions)

        // Transpose and remove single_end from meta - how to just remove one element?
        FASTP.out.reads
            .transpose()
            .map{ meta, split_fastq -> [ [
                'id'         : meta['id'],
                'family_id'  : meta['family_id'],
                'paternal_id': meta['paternal_id'],
                'maternal_id': meta['maternal_id'],
                'sex'        : meta['sex'],
                'phenotype'  : meta['phenotype'],
                ], split_fastq ]
            }
            .set { ch_split_reads }

        MINIMAP2_ALIGN_SPLIT ( ch_split_reads, ch_index, true, false, false )
        ch_versions = ch_versions.mix(MINIMAP2_ALIGN_SPLIT.out.versions)

        MINIMAP2_ALIGN_SPLIT.out.bam
            .groupTuple() // Collect aligned files per sample
            .set{ ch_samtools_sort_in }

        // Make one BAM per sample
        SAMTOOLS_SORT ( ch_samtools_sort_in, [[],[]] )
        ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions)

        SAMTOOLS_SORT.out.bam
            .join( SAMTOOLS_SORT.out.csi )
            .set { ch_bam_csi_multi }

        // Gather files
        ch_bam     = ch_bam.mix(SAMTOOLS_SORT.out.bam)
        ch_csi     = ch_csi.mix(SAMTOOLS_SORT.out.csi)
        ch_bam_csi = ch_bam_csi.mix(ch_bam_csi_multi)

    } else {

        MINIMAP2_ALIGN_UNSPLIT ( ch_sample, ch_index, true, false, false )
        ch_versions = ch_versions.mix(MINIMAP2_ALIGN_UNSPLIT.out.versions)

        MINIMAP2_ALIGN_UNSPLIT.out.bam
            .join(MINIMAP2_ALIGN_UNSPLIT.out.csi)
            .set{ ch_bam_csi_single }

        // Gather files
        ch_bam     = ch_bam.mix(MINIMAP2_ALIGN_UNSPLIT.out.bam)
        ch_csi     = ch_csi.mix(MINIMAP2_ALIGN_UNSPLIT.out.csi)
        ch_bam_csi = ch_bam_csi.mix(ch_bam_csi_single)
    }

    emit:
    bam      = ch_bam       // channel: [ val(meta), bam ]
    csi      = ch_csi       // channel: [ val(meta), csi ]
    bam_csi  = ch_bam_csi   // channel: [ val(meta), bam, csi]
    versions = ch_versions  // channel: [ versions.yml ]
}

