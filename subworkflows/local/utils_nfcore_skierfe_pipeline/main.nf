//
// Subworkflow with functionality specific to the genomic-medicine-sweden/skierfe pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFVALIDATION_PLUGIN } from '../../nf-core/utils_nfvalidation_plugin'
include { paramsSummaryMap          } from 'plugin/nf-validation'
include { fromSamplesheet           } from 'plugin/nf-validation'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { dashedLine                } from '../../nf-core/utils_nfcore_pipeline'
include { nfCoreLogo                } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification            } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { workflowCitation          } from '../../nf-core/utils_nfcore_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DEFINE DEPENDENCIES (FILES AND WORKFLOWS) FOR OTHER WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// nf-validation does not support contitional file and params validation,
// add these here.
//
// For example:
// Workflow skip_cnv_calling can't be run _with_ skip_short_variant_calling
// File dipcall_par must be set not using skip_assembly_wf
// Preset "pacbio" can't be run _without_ skip_methylation_wf
//

def parameterDependencies = [
    "workflow": [
        "skip_assembly_wf"          : [],
        "skip_short_variant_calling": ["skip_mapping_wf"],
        "skip_snv_annotation"       : ["skip_mapping_wf", "skip_short_variant_calling"],
        "skip_cnv_calling"          : ["skip_mapping_wf", "skip_short_variant_calling"],
        "skip_phasing_wf"           : ["skip_mapping_wf", "skip_short_variant_calling"],
        "skip_repeat_wf"            : ["skip_mapping_wf", "skip_short_variant_calling", "skip_phasing_wf"],
        "skip_methylation_wf"       : ["skip_mapping_wf", "skip_short_variant_calling", "skip_phasing_wf"],
    ],
    "files": [
        "dipcall_par"    : ["skip_assembly_wf"],
        "snp_db"         : ["skip_snv_annotation"],
        "vep_cache"      : ["skip_snv_annotation"],
        "hificnv_xy"     : ["skip_cnv_calling"],
        "hificnv_xx"     : ["skip_cnv_calling"],
        "hificnv_exclude": ["skip_cnv_calling"],
        "trgt_repeats"   : ["skip_repeat_wf"],
    ],
    "preset": [
        "pacbio" : ["skip_methylation_wf"],
        "ONT_R10": ["skip_assembly_wf", "skip_cnv_calling"],
        "revio"  : [],
    ]
]

def parameterStatus = [
    "workflow": [
        skip_short_variant_calling: params.skip_short_variant_calling,
        skip_phasing_wf:            params.skip_phasing_wf,
        skip_methylation_wf:        params.skip_methylation_wf,
        skip_repeat_wf:             params.skip_repeat_wf,
        skip_snv_annotation:        params.skip_snv_annotation,
        skip_cnv_calling:           params.skip_cnv_calling,
        skip_mapping_wf:            params.skip_mapping_wf,
        skip_qc:                    params.skip_qc,
        skip_assembly_wf:           params.skip_assembly_wf,
    ],
    "files": [
        dipcall_par    : params.dipcall_par,
        snp_db         : params.snp_db,
        vep_cache      : params.vep_cache,
        hificnv_xy     : params.hificnv_xy,
        hificnv_xx     : params.hificnv_xx,
        hificnv_exclude: params.hificnv_exclude,
        trgt_repeats   : params.trgt_repeats,
    ],
    "preset": [
        pacbio : params.preset == "pacbio",
        revio  : params.preset == "revio",
        ONT_R10: params.preset == "ONT_R10",
    ]
]

/*
========================================================================================
    SUBWORKFLOW TO INITIALISE PIPELINE
========================================================================================
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    help              // boolean: Display help text
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input             //  string: Path to input samplesheet

    main:
    ch_versions = Channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    pre_help_text = nfCoreLogo(monochrome_logs)
    post_help_text = '\n' + workflowCitation() + '\n' + dashedLine(monochrome_logs)
    def String workflow_command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"
    UTILS_NFVALIDATION_PLUGIN (
        help,
        workflow_command,
        pre_help_text,
        post_help_text,
        validate_params,
        "nextflow_schema.json"
    )
    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )
    //
    // Custom validation for pipeline parameters
    //
    validateInputParameters(parameterDependencies, parameterStatus)

    //
    // Create channel from input file provided through params.input
    //
    Channel
        .fromSamplesheet("input")
        .map {
            validateInputSamplesheet(it)
        }
        .set { ch_samplesheet }

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
========================================================================================
    SUBWORKFLOW FOR PIPELINE COMPLETION
========================================================================================
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        //  string: hook URL for notifications
    multiqc_report  //  string: Path to MultiQC report

    main:

    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(summary_params, email, email_on_fail, plaintext_email, outdir, monochrome_logs, multiqc_report.toList())
        }

        completionSummary(monochrome_logs)

        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }
}

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/
//
// Check and validate pipeline parameters
//
def validateInputParameters(map, params) {
    genomeExistsError()
    validateParameterCombinations(map, params)
}

//
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    return input
}
//
// Get attribute from genome config file e.g. fasta
//
def getGenomeAttribute(attribute) {
    if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
        if (params.genomes[ params.genome ].containsKey(attribute)) {
            return params.genomes[ params.genome ][ attribute ]
        }
    }
    return null
}

//
// Exit pipeline if incorrect --genome key provided
//
def genomeExistsError() {
    if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
        def error_string = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" +
            "  Genome '${params.genome}' not found in any config files provided to the pipeline.\n" +
            "  Currently, the available genome keys are:\n" +
            "  ${params.genomes.keySet().join(", ")}\n" +
            "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        error(error_string)
    }
}

//
// Generate methods description for MultiQC
//
def toolCitationText() {
    // TODO nf-core: Optionally add in-text citation tools to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "Tool (Foo et al. 2023)" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def citation_text = [
            "Tools used in the workflow included:",
            "FastQC (Andrews 2010),",
            "MultiQC (Ewels et al. 2016)",
            "."
        ].join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    // TODO nf-core: Optionally add bibliographic entries to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "<li>Author (2023) Pub name, Journal, DOI</li>" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def reference_text = [
            "<li>Andrews S, (2010) FastQC, URL: https://www.bioinformatics.babraham.ac.uk/projects/fastqc/).</li>",
            "<li>Ewels, P., Magnusson, M., Lundin, S., & Käller, M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics , 32(19), 3047–3048. doi: /10.1093/bioinformatics/btw354</li>"
        ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    meta["doi_text"] = meta.manifest_map.doi ? "(doi: <a href=\'https://doi.org/${meta.manifest_map.doi}\'>${meta.manifest_map.doi}</a>)" : ""
    meta["nodoi_text"] = meta.manifest_map.doi ? "": "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // Tool references
    meta["tool_citations"] = ""
    meta["tool_bibliography"] = ""

    // TODO nf-core: Only uncomment below if logic in toolCitationText/toolBibliographyText has been filled!
    // meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    // meta["tool_bibliography"] = toolBibliographyText()


    def methods_text = mqc_methods_yaml.text

    def engine =  new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}

//
// Validate preset and workflow skip combinations
//
def validateParameterCombinations(combinationsMap, statusMap) {
    // Array to store errors
    def errors = []
    // For each command-line argType (preset, workflow-skip)
    statusMap.each { argType, args ->
        // Iterate over these arguments
        args.each { arg, argIsActive ->
            // Collect what workflows are needed for a preset / or workflow(s) that depend on a workflow
            // Or lookup all workflows that depend on the skip (workflow)
            def dependencies
            if (argType == "preset") {
                dependencies = combinationsMap[argType][arg]
            } else if (argType == "workflow"){
                dependencies = getSkipsWithWorkflowDependency(arg, combinationsMap[argType])
            } else if (argType == "files") {
                // Not the most graceful solution but it works
                checkFileDependencies(arg, combinationsMap, statusMap, errors)
                return // Exit early
            }
            def dependencyString = dependencies.collect { "--$it" }.join(" ")
            // If arg is set on the command line and has dependencies not currently active
            if (argIsActive && dependencyString) {
                formattedArg = (argType == "preset") ? "--preset " + arg : "--" + arg
                errors << "Whenever $formattedArg is active, the pipeline has to be run with: $dependencyString."
            }
        }
    }
    // Give error if there are any
    if(errors) {
        def error_string = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" +
                           "  " + errors.join("\n  ") + "\n" +
                           "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        error(error_string)
    }
}

//
// Lookup all other workflows that needs to be active for a certain workflow
//
def getSkipsWithWorkflowDependency(String workflow, map) {
    def keys = map.findAll { it.value.contains(workflow) }.keySet()
    return keys as List
}
//
// Lookup if a file is required by any workflows, and add to errors
//
def checkFileDependencies(String fileParam, Map combinationsMap, Map statusMap, List errors) {
    // Get the the workflow required by file
    def workflowThatRequiresFile = combinationsMap["files"][fileParam][0]
    // Get status of that workflow
    def WorkflowIsOff = statusMap["workflow"][workflowThatRequiresFile]
    def WorkflowIsActive = !WorkflowIsOff
    // Get the file path
    def FilePath = statusMap["files"][fileParam]
    // If the workflow that requires the file is active & theres no file available
    if(WorkflowIsActive && FilePath == null) {
        errors << "When running without $workflowThatRequiresFile, --$fileParam is required."
    }
    return errors
}
