# genomic-medicine-sweden/nallo: Output

## Table of contents

- [genomic-medicine-sweden/nallo: Output](#genomic-medicine-swedennallo-output)
  - [Table of contents](#table-of-contents)
  - [Pipeline overview](#pipeline-overview)
    - [Alignment](#alignment)
    - [Assembly](#assembly)
    - [Assembly variant calling](#assembly-variant-calling)
    - [CNV calling](#cnv-calling)
    - [Methylation](#methylation)
    - [MultiQC](#multiqc)
    - [Paraphase](#paraphase)
    - [Phasing](#phasing)
    - [Pipeline information](#pipeline-information)
    - [Aligned read QC](#aligned-read-qc)
      - [Mosdepth](#mosdepth)
      - [Cramino](#cramino)
      - [Somalier](#somalier)
    - [Raw read QC](#raw-read-qc)
      - [FastQC](#fastqc)
    - [Repeat calling](#repeat-calling)
    - [Repeat annotation](#repeat-annotation)
    - [SNV Annotation](#snv-annotation)
    - [Ranked Variants](#ranked-variants)
    - [SV Calling](#sv-calling)

## Pipeline overview

The directories listed below will be created in the results directory after the pipeline has finished:

- `aligned_reads`
- `assembly_haplotypes`
- `assembly_variant_calling`
- `cnv_calling`
- `methylation`
- `multiqc`
- `paraphase`
- `phasing`
- `pipeline_info`
- `qc_aligned_reads`
- `qc_raw_reads`
- `repeat_calling`
- `snv_annotation`
- `snv_calling`
- `sv_calling`

### Alignment

[minimap2](https://github.com/lh3/minimap2) is used to map the reads to a reference genome. The aligned reads are sorted, (merged) and indexed using [samtools](https://github.com/samtools/samtools).

<details markdown="1">
<summary>Output files from Alignment</summary>

- `{outputdir}/aligned_reads/minimap2/{sample}/`
  - `*.bam`: Alignment file in bam format
  - `*.bai`: Index of the corresponding bam file
  </details>

### Assembly

[hifiasm](https://github.com/chhylp123/hifiasm) is used to assemble genomes. The assembled haplotypes are then comverted to fasta files using [gfastats](https://github.com/vgl-hub/gfastats).

<details markdown="1">
<summary>Output files from Assembly</summary>

- `{outputdir}/assembly_haplotypes/gfastats/{sample}/`
  - `*hap1.p_ctg.fasta.gz`: Assembled haplotype 1
  - `*hap2.p_ctg.fasta.gz`: Assembled haplotype 2
  - `*.assembly_summary`: Summary statistics
  </details>

### Assembly variant calling

A deconstructed version of [dipcall](https://github.com/lh3/dipcall) is used to call variants from the assembled haplotypes. They are also mapped back to the reference genome.

<details markdown="1">
<summary>Output files from Assembly variant calling</summary>

> Dipcall produces several files, a full expanation is available [here](https://github.com/lh3/dipcall).

- `{outputdir}/assembly_variant_calling/dipcall/{sample}/`

  - `*hap1.bam`: Assembled haplotype 1 mapped to the reference genome
  - `*hap1.bai`: Index of the corresponding bam file.
  - `*hap2.bam`: Assembled haplotype 2 mapped to the reference genome
  - `*hap2.bai`: Index of the corresponding bam file.

  </details>

### CNV calling

[HiFiCNV](https://github.com/PacificBiosciences/HiFiCNV) is used to call CNVs. It also produces copynumber, depth and MAF tracks loadable in IGV.

<details markdown="1">
<summary>Output files from CNV calling</summary>

- `{outputdir}/cnv_calling/hificnv/{sample}/`
  - `*.copynum.bedgraph`: Copy number in bedgraph format
  - `*.depth.bw`: Depth track in BigWig format
  - `*.maf.bw`: Minor allele frequencies in BigWig format
  - `*.vcf.gz`: VCF file containing CNV variants
  - `*.vcf.gz.tbi`: Index of the corresponding VCF file
  </details>

### Methylation

[modkit](https://github.com/nanoporetech/modkit) is used to create methylation pileups. bedMethyl files are stored both one file with summary counts from reads per haplotag (e.g. HP1, HP2 and ungrouped) and one file with summary counts from all reads. The methylation is also stored in the BAM files and can be viewed directly in IGV.

<details markdown="1">
<summary>Output files from Methylation</summary>

- `{outputdir}/methylation/modkit/pileup/phased/{sample}/`

  - `*.modkit_pileup_phased_*.bed.gz`: bedMethyl file containing summary counts from reads with haplotags, e.g. 1 or 2
  - `*.modkit_pileup_phased_ungrouped.bed.gz`: bedMethyl file containing summary counts for ungrouped reads
  - `*.bed.gz.tbi`: Index of the corresponding bedMethyl file

- `{outputdir}/methylation/modkit/pileup/unphased/{sample}/`
  - `*.modkit_pileup.bed.gz`: bedMethyl file containing summary counts from all reads
  - `*.bed.gz.tbi`: Index of the corresponding bedMethyl file
  </details>

### MultiQC

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

<details markdown="1">
<summary>Output files</summary>

- `{outputdir}/multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.
  </details>

### Paraphase

[Paraphase](https://github.com/PacificBiosciences/paraphase) is used to call paralogous genes. For interpreting the output, see <https://github.com/PacificBiosciences/paraphase>.

<details markdown="1">
<summary>Output files from Paraphase</summary>

- `{outputdir}/paraphase/{sample}/`
  - `*.bam`: BAM file with haplotypes grouped by HP and colored by YC
  - `*.bai`: Index of the corresponding bam file.
  - `*.json`: Output file summarizing haplotypes and variant calls
  - `{sample}_paraphase_vcfs/`:
    - `{sample}_{gene}_vcf`: VCF file per gene
    - `{sample}_{gene}_vcf.tbi`: Index of the corresponding VCF file
    </details>

### Phasing

[WhatsHap](https://whatshap.readthedocs.io/en/latest/) or [HiPhase](https://github.com/PacificBiosciences/HiPhase) are used to phase variants and haplotag reads.

<details markdown="1">
<summary>Output files from WhatsHap</summary>

- `{outputdir}/aligned_reads/{sample}/`
  - `{sample}_phased.bam`: BAM file with haplotags
  - `{sample}_phased.bam.bai`: Index of the corresponding bam file
- `{outputdir}/phasing/whatshap/phase/{sample}/`
  - `*.vcf.gz`: VCF file with phased variants
  - `*.vcf.gz.tbi`: Index of the corresponding VCF file
- `{outputdir}/phasing/whatshap/stats/{sample}/`
  - `*.blocks.tsv`: File with phase blocks
  - `*.stats.tsv`: File with phasing statistics
  </details>

<details markdown="1">
<summary>Output files from HiPhase</summary>

- `{outputdir}/aligned_reads/{sample}/`

  - `{sample}_phased.bam`: BAM file with haplotags
  - `{sample}_phased.bam.bai`: Index of the corresponding bam file

- `{outputdir}/phasing/hiphase/{snv,sv}/{sample}/`

  - `*.blocks.tsv`: File with phase blocks
  - `*.stats.tsv.gz`: File with phasing statistics
  - `*.vcf.gz`: VCF file with phased variants
  - `*.vcf.gz.tbi`: Index of the corresponding VCF file
  - `*.summary.tsv`: HiPhase summary file

  </details>

### Pipeline information

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

### Aligned read QC

[cramino](https://github.com/wdecoster/cramino), [mosdepth](https://github.com/brentp/mosdepth) and [somalier](https://github.com/brentp/somalier) are used for aligned read QC.

##### Mosdepth

[Mosdepth](https://github.com/brentp/mosdepth) is used to report quality control metrics such as coverage, and GC content from alignment files.

<details markdown="1">
<summary>Output files from Mosdepth</summary>

- `{outputdir}/qc_aligned_reads/mosdepth/{sample}`
  - `*.mosdepth.global.dist.txt`: This file contains a cumulative distribution indicating the proportion of total bases that were covered for at least a given coverage value across each chromosome and the whole genome
  - `*.mosdepth.region.dist.txt`: This file contains a cumulative distribution indicating the proportion of total bases that were covered for at least a given coverage value across each region, is output if running the pipeline with a BED-file
  - `*.mosdepth.summary.txt`: Mosdepth ummary file
  - `*.regions.bed.gz`: Depth per region, is output if running the pipeline with a BED-file
  - `*.regions.bed.gz.csi`: Index of regions.bed.gz
  </details>

##### Cramino

[cramino](https://github.com/wdecoster/cramino) is run on both phased and unphased reads.

<details markdown="1">
<summary>Output files from Cramino</summary>

- `{outputdir}/qc_aligned_reads/cramino/phased/{sample}`
  - `*.arrow`: Read length and quality in [Apache Arrow](https://arrow.apache.org/docs/format/Columnar.html) format
  - `*.txt`: Summary information in text format
- `{outputdir}/qc_aligned_reads/cramino/unphased/{sample}`
  - `*.arrow`: Read length and quality in [Apache Arrow](https://arrow.apache.org/docs/format/Columnar.html) format
  - `*.txt`: Summary information in text format
  </details>

##### Somalier

[somalier](https://github.com/brentp/somalier) is used to check relatedness and sex.

<details markdown="1">
<summary>Output files from Somalier</summary>

- `{outputdir}/qc_aligned_reads/somalier/relate/{project}/`
  - `{project}.html`: HTML report
  - `{project}.pairs.tsv`: Output information in sample pairs
  - `{project}.samples.tsv`: Output information per sample
  </details>

### Raw read QC

[cramino](https://github.com/wdecoster/cramino), [mosdepth](https://github.com/brentp/mosdepth) and [somalier](https://github.com/brentp/somalier) are used for aligned read QC.

##### FastQC

[FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) gives general quality metrics about your sequenced reads. It provides information about the quality score distribution across your reads, per base sequence content (%A/T/G/C), adapter contamination and overrepresented sequences. For further reading and documentation see the [FastQC help pages](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/).

<details markdown="1">
<summary>Output files</summary>

- `{outputdir}/qc_raw_reads/fastqc/{sample}/`
  - `*_fastqc.html`: FastQC report containing quality metrics.
  - `*_fastqc.zip`: Zip archive containing the FastQC report, tab-delimited data file and plot images.
  </details>

### Repeat calling

[TRGT](https://github.com/PacificBiosciences/trgt) is used to call repeats.

<details markdown="1">
<summary>Output files from TRGT</summary>

- `{outputdir}/repeat_calling/trgt/multi_sample/{project}/`
  - `*.vcf.gz`: Merged VCF for all samples
  - `*.vcf.gz.tbi`: Index of the corresponding VCF file
- `{outputdir}/repeat_calling/trgt/single_sample/{sample}/`
  - `*.vcf.gz`: VCF with called repeats
  - `*.vcf.gz.tbi`: Index of the corresponding VCF file
  - `*.bam`: BAM file with sorted spanning reads
  - `*.bai`: Index of the corresponding bam file
  </details>

### Repeat annotation

[Stranger](https://github.com/Clinical-Genomics/stranger) is used to annotate repeats.

<details markdown="1">
<summary>Output files from Stranger</summary>

- `{outputdir}/repeat_annotation/stranger/{sample}`
  - `*.vcf.gz`: Annotated VCF
  - `*.vcf.gz.tbi`: Index of the corresponding VCF file
  </details>

### SNV Annotation

[echtvar](https://github.com/brentp/echtvar) and [VEP](https://www.ensembl.org/vep) are used to annotate small variants.
[bcftools](https://samtools.github.io/bcftools/) is used to generate statistics.

<details markdown="1">
<summary>Output files from SNV Annotation</summary>

- `{outputdir}/databases/echtvar/encode/{project}/`
  - `*.zip`: Database with AF and AC for all samples run
- `{outputdir}/snvs/{single_sample,multi_sample/{project}/`
  - `*_snvs_annotated*.vcf.gz`: VCF with annotated variants
  - `*_snvs_annotated*.vcf.gz.tbi`: Index of the corresponding VCF file
- `{outputdir}/snvs/stats/single_sample/`
  - `*.stats.txt`: Variant statistics
  </details>

### Ranked variants

#### Filter_vep

[filter_vep from VEP](https://www.ensembl.org/info/docs/tools/vep/script/vep_filter.html) is used to subset the variants based on a list of HGNC ID:s. Typical use case is that you want to filter your results to only include variants in a predefined set of clinically relevant genes. This step is optional and can be disabled by using the flag `--skip_vep_filter`. You will always get the complete VCF together with the clinical VCF.

#### GENMOD

[GENMOD](https://github.com/Clinical-Genomics/genmod) is a simple to use command line tool for annotating and analyzing genomic variations in the VCF file format. GENMOD can annotate genetic patterns of inheritance in vcf files with single or multiple families of arbitrary size. Each variant will be assigned a predicted pathogenicity score. The score will be given both as a raw score and a normalized score with values between 0 and 1. The tags in the INFO field are `RankScore` and `RankScoreNormalized`. The score can be configured to fit your annotations and preferences by modifying the score config file.

<details markdown="1">
<summary>Output files</summary>

- `{outputdir}/snvs/single_sample/{sample}/`
  - `{sample}_snv_annotated_ranked.vcf.gz`: VCF with annotated and ranked variants
  - `{sample}_snv_annotated_ranked.vcf.gz.tbi`: Index of the corresponding VCF file
- `{outputdir}/snvs/multi_sample/{project}/`
  - `{project}_snv_annotated_ranked.vcf.gz`: VCF with annotated and ranked variants
  - `{project}_snv_annotated_ranked.vcf.gz.tbi`: Index of the corresponding VCF file
  </details>

### SV Calling

[Sniffles](https://github.com/fritzsedlazeck/Sniffles) is used to call and merge structural variants.

<details markdown="1">
<summary>Output files from SNV Calling</summary>

- `{outputdir}/sv_calling/multi_sample/{project}`
  - `*.vcf.gz`: VCF with variants
  - `*.vcf.gz.tbi`: Index of the corresponding VCF file
- `{outputdir}/sv_calling/single_sample/{sample}`
  - `*.snf`: Sniffles SNF file
  - `*.vcf.gz`: VCF with variants
  - `*.vcf.gz.tbi`: Index of the corresponding VCF file
  </details>
