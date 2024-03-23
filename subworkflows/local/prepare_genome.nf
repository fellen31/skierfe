include { BUILD_INTERVALS  } from '../../modules/local/build_intervals/main'
include { GUNZIP           } from '../../modules/nf-core/gunzip/main'
include { SAMTOOLS_FAIDX   } from '../../modules/nf-core/samtools/faidx/main'
include { SPLIT_BED_CHUNKS } from '../../modules/local/split_bed_chunks/main'

workflow PREPARE_GENOME {

    take:
    fasta    // channel: [ val(meta), fasta ]
    bed      // channel: [ val(meta), fasta ]
    make_bed // channel: bool
    split_n  // channel: val

    main:
    ch_versions = Channel.empty()

    // Will not catch cases where fasta is bgzipped
    if (params.fasta.endsWith('.gz')) {
        GUNZIP( fasta )
            .gunzip
            .collect()
            .set { ch_fasta }

        ch_versions = ch_versions.mix(GUNZIP.out.versions)
    } else {
        fasta_in
            .set { ch_fasta }
    }

    SAMTOOLS_FAIDX ( ch_fasta, [[],[]] )
    ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)

    SAMTOOLS_FAIDX.out.fai
        .collect()
        .set { ch_fai }

    if(make_bed == true) {
        ch_fai
            .map { name, fai -> [ [ 'id' : name ], fai ] }
            .set { ch_build_intervals_in }

        BUILD_INTERVALS( ch_build_intervals_in )
        ch_versions = ch_versions.mix(BUILD_INTERVALS.out.versions)

        BUILD_INTERVALS.out.bed
            .set { ch_bed }
    } else {
        bed
            .set { ch_bed }
    }

    SPLIT_BED_CHUNKS ( ch_bed, split_n )
    //Missing!: ch_versions = ch_versions.mix(SPLIT_BED_CHUNKS.out.versions)

    emit:
    fasta     = ch_fasta                         // channel: [ val(meta), fasta ]
    fai       = SAMTOOLS_FAIDX.out.fai.collect() // channel: [ val(meta), fai ]
    bed       = ch_bed.collect()                 // channel: [ val(meta), bed ]
    split_bed = SPLIT_BED_CHUNKS.out.split_beds  // channel: [ val(meta), [ split_beds ] ]
    versions  = ch_versions                      // channel: [ versions.yml ]
}
