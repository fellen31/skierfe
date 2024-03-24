include { DEEPVARIANT                               } from '../../modules/nf-core/deepvariant'
include { DEEPVARIANT as MAKE_EXAMPLES              } from '../../modules/local/deepvariant/make_examples'
include { DEEPVARIANT as CALL_VARIANTS              } from '../../modules/local/deepvariant/call_variants'
include { DEEPVARIANT as CALL_VARIANTS_GPU          } from '../../modules/local/deepvariant/call_variants_gpu'
include { DEEPVARIANT as POSTPROCESS_VARIANTS       } from '../../modules/local/deepvariant/postprocess_variants'
include { GLNEXUS                                   } from '../../modules/nf-core/glnexus'
include { BCFTOOLS_VIEW_REGIONS                     } from '../../modules/local/bcftools/view_regions'
include { TABIX_TABIX as TABIX_EXTRA_GVCFS          } from '../../modules/nf-core/tabix/tabix/main'
include { TABIX_TABIX as TABIX_DV                   } from '../../modules/nf-core/tabix/tabix/main'
include { TABIX_TABIX as TABIX_DV_VCF               } from '../../modules/nf-core/tabix/tabix/main'
include { TABIX_TABIX as TABIX_GLNEXUS              } from '../../modules/nf-core/tabix/tabix/main'
include { BCFTOOLS_CONCAT as BCFTOOLS_CONCAT_DV     } from '../../modules/nf-core/bcftools/concat/main'
include { BCFTOOLS_CONCAT as BCFTOOLS_CONCAT_DV_VCF } from '../../modules/nf-core/bcftools/concat/main'
include { BCFTOOLS_SORT as BCFTOOLS_SORT_DV         } from '../../modules/nf-core/bcftools/sort/main'
include { BCFTOOLS_SORT as BCFTOOLS_SORT_DV_VCF     } from '../../modules/nf-core/bcftools/sort/main'

// TODO: Fix DV_VCF output dir, and change DV to DV_GVCF for clarity

workflow SHORT_VARIANT_CALLING {

    take:
    ch_bam_csi     // channel: [ val(meta), bam, csi, split_bed ]
    ch_extra_gvcfs // channel: [ val(meta), gvcf ] -- broken
    ch_fasta       // channel: [ val(meta), fasta ]
    ch_fai         // channel: [ val(meta), fai ]
    ch_bed         // channel: [ val(meta), bed ]

    main:
    ch_snp_calls_vcf  = Channel.empty()
    ch_snp_calls_gvcf = Channel.empty()
    ch_combined_bcf   = Channel.empty()
    ch_versions       = Channel.empty()

    DEEPVARIANT ( ch_bam_csi, ch_fasta, ch_fai, [[],[]] )

    def start = 0 // Has to be 0
    def end = 13 // Hsa to be bigger than 0
    def step = 1 // should be task.cpus - ish
    // Create a channel for each range
    Channel.from(start..(end - 1))
        .collate(step)
        .map { it -> [ it ] }
        .set{task}

    ch_bam_csi
        .map { meta, bam, csi, bed -> [ meta + [ 'bed': bed.name ], bam, csi, bed ] }
        .combine(task)
        .set { ch_make_examples }
    MAKE_EXAMPLES ( ch_make_examples, ch_fasta, ch_fai, [[],[]], end )

    ch_called_variants = Channel.empty()
    if(params.gpu) {
        CALL_VARIANTS_GPU ( MAKE_EXAMPLES.out.examples.transpose(), end )
        ch_called_variants = CALL_VARIANTS_GPU.out.variants
    } else {
        CALL_VARIANTS ( MAKE_EXAMPLES.out.examples.transpose(), end )
        ch_called_variants = CALL_VARIANTS.out.variants
    }
    ch_called_variants
        .groupTuple()
        .join(MAKE_EXAMPLES.out.gvcf.transpose().groupTuple())
        .set { ch_postprocess_variants }
    POSTPROCESS_VARIANTS ( ch_postprocess_variants, ch_fasta, ch_fai, end )
    // Collect VCFs
    ch_snp_calls_vcf  = ch_snp_calls_vcf.mix(DEEPVARIANT.out.vcf)

    // Collect GVCFs
    ch_snp_calls_gvcf = ch_snp_calls_gvcf.mix(DEEPVARIANT.out.gvcf)

    // TODO: This only works with DeepVariant for now (remove PEPPER_MARGIN_DEEPVARIANT/Deeptrio?)

    // Extra gVCFs
    TABIX_EXTRA_GVCFS(ch_extra_gvcfs)

    ch_extra_gvcfs
        .join(TABIX_EXTRA_GVCFS.out.tbi)
        .groupTuple()
        .set{ ch_bcftools_view_regions_in }

    // This cuts all regions in BED file from extra gVCFS, better than nothing
    BCFTOOLS_VIEW_REGIONS( ch_bcftools_view_regions_in, ch_bed )

    // DV gVCFs
    TABIX_DV(ch_snp_calls_gvcf)

    ch_snp_calls_gvcf
        .groupTuple() // size not working here if there are less than specifed regions..
        .join(TABIX_DV.out.tbi.groupTuple())
        .set{ bcftools_concat_dv_in }


    // Concat into one gVCF per sample & sort
    BCFTOOLS_CONCAT_DV ( bcftools_concat_dv_in )
    BCFTOOLS_SORT_DV   ( BCFTOOLS_CONCAT_DV.out.vcf )

    // DV VCFs
    TABIX_DV_VCF(ch_snp_calls_vcf)

    ch_snp_calls_vcf
        .groupTuple() // size not working here if there are less than specifed regions..
        .join(TABIX_DV_VCF.out.tbi.groupTuple())
        .set{ bcftools_concat_dv_vcf_in }


    // Concat into one VCF per sample & sort
    BCFTOOLS_CONCAT_DV_VCF ( bcftools_concat_dv_vcf_in )
    BCFTOOLS_SORT_DV_VCF   ( BCFTOOLS_CONCAT_DV_VCF.out.vcf )

    // Put DV and extra gvCFs together -> send to glnexus
    BCFTOOLS_SORT_DV.out.vcf
        .concat(BCFTOOLS_VIEW_REGIONS.out.vcf)
        .map { meta, gvcf -> [ ['id':'multisample'], gvcf ]}
        .groupTuple()
        .set{ ch_glnexus_in }

    // Multisample
    GLNEXUS( ch_glnexus_in, ch_bed )
    TABIX_GLNEXUS(GLNEXUS.out.bcf)

    // Get versions
    ch_versions = ch_versions.mix(DEEPVARIANT.out.versions)
    ch_versions = ch_versions.mix(GLNEXUS.out.versions)
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW_REGIONS.out.versions)
    ch_versions = ch_versions.mix(TABIX_EXTRA_GVCFS.out.versions)
    ch_versions = ch_versions.mix(TABIX_DV.out.versions)
    ch_versions = ch_versions.mix(BCFTOOLS_CONCAT_DV.out.versions)
    ch_versions = ch_versions.mix(BCFTOOLS_SORT_DV.out.versions)
    ch_versions = ch_versions.mix(TABIX_GLNEXUS.out.versions)


    emit:
    snp_calls_vcf = BCFTOOLS_SORT_DV_VCF.out.vcf
    combined_bcf  = GLNEXUS.out.bcf
    versions      = ch_versions
}
