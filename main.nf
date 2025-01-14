/*
========================================================================================
                 FILE Download Statistics Workflow
========================================================================================
 @#### Authors
 Suresh Hewapathirana <sureshhewabi@gmail.com>
----------------------------------------------------------------------------------------
*/

/*
 * Define the default parameters
 */
params.root_dir=''
params.output_file='parsed_data.parquet'
params.log_file=''
params.api_endpoint_file_download_per_project=''
params.api_endpoint_header=''
params.protocols=''


log.info """\
 ===================================================
  F I L E    D O W N L O A D    S T A T I S T I C S
 ===================================================


FOR DEVELOPERS USE

SessionId           : $workflow.sessionId
LaunchDir           : $workflow.launchDir
projectDir          : $workflow.projectDir
workDir             : $workflow.workDir
RunName             : $workflow.runName
NextFlow version    : $nextflow.version
Nextflow location   : ${params.nextflow_location}
Date                : ${new java.util.Date()}
Protocols           : ${params.protocols}
Resource Identifiers: ${params.resource_identifiers}
Completeness        : ${params.completeness}
Public/Private      : ${params.public_private}
Report Template     : ${params.report_template}
Batch Size          : ${params.log_file_batch_size}
Resource Base URL   : ${params.resource_base_url}
Report copy location: ${params.report_copy_filepath}
Skipped Years       : ${params.skipped_years}
Accession Pattern   : ${params.accession_pattern}

 """

process get_log_files {

    label 'data_mover'

    input:
    val root_dir

    output:
    path "file_list.txt"

    script:
    """
    python3 ${workflow.projectDir}/filedownloadstat/main.py get_log_files \
        --root_dir $root_dir \
        --output "file_list.txt" \
        --protocols "${params.protocols.join(',')}" \
        --public "${params.public_private.join(',')}"
    """
}

process run_log_file_stat{
    label 'process_low'

    input:
    val file_paths  // Input the file generated by get_log_files

    output:
    path "log_file_statistics.html"  // Output the visualizations as an HTML report

    script:
    """
    python3 ${workflow.projectDir}/filedownloadstat/main.py run_log_file_stat \
        --file ${file_paths} \
        --output "log_file_statistics.html"
    """
}

process process_log_file {

    label 'process_very_low'
    label 'data_mover'


    input:
    val file_path  // Each file object from the channel

    output:
    path "*.parquet",optional: true  // Output files with unique names

    script:
    """
    # Extract a unique identifier from the log file name
    filename=\$(basename ${file_path} .log.tsv.gz)
    python3 ${workflow.projectDir}/filedownloadstat/main.py process_log_file \
        -f ${file_path} \
        -o "\${filename}.parquet" \
        -r "${params.resource_identifiers.join(",")}" \
        -c "${params.completeness.join(",")}" \
        -b ${params.log_file_batch_size} \
        -a ${params.accession_pattern} \
        > process_log_file.log 2>&1
    """
}

process analyze_parquet_files {

    label 'process_low'

    input:
    val all_parquet_files  // A comma-separated string of file paths

    output:
    path("file_download_counts.json"), emit: file_download_counts
    path("summed_accession_counts.json"), emit: summed_accession_counts
    path("all_data.json"), emit: all_data

    script:
    """
    # Write the file paths to a temporary file, because otherwise Argument list(file list) will be too long
    echo "${all_parquet_files.join('\n')}" > all_parquet_files_list.txt

    python3 ${workflow.projectDir}/filedownloadstat/main.py get_file_counts \
        --input_dir all_parquet_files_list.txt \
        --output_grouped file_download_counts.json \
        --output_summed summed_accession_counts.json \
        --all_data all_data.json
    """
}

process run_file_download_stat {
    label 'process_low'

    input:
    path all_data  // Input the file generated by analyze_parquet_files

    output:
    path "file_download_stat.html"  // Output the visualizations as an HTML report

    script:
    """
    python3 ${workflow.projectDir}/filedownloadstat/main.py run_file_download_stat \
        --file ${all_data} \
        --output "file_download_stat.html" \
        --report_template ${params.report_template} \
        --baseurl ${params.resource_base_url} \
        --report_copy_filepath ${params.report_copy_filepath} \
        --skipped_years "${params.skipped_years.join(',')}"
    """
}


process uploadJsonFile {

    input:
    path jsonFile // The JSON file to upload

    output:
    path "upload_response.txt" // Capture the response from the server

    script:
    """
    curl --location '${params.api_endpoint_file_download_per_project}' \
    --header '${params.api_endpoint_header}' \
    --form 'files=@\"${jsonFile}\"' > upload_response.txt
    """
}


workflow {
    // Step 1: Gather file names
    def root_dir = params.root_dir
    def file_paths = get_log_files(root_dir)

    // Step 2: Run statistics in parallel with processing log files
    def stats_file = run_log_file_stat(file_paths)

    file_paths
        .splitText()                // Split file_list.txt into individual lines
        .map { it.split('\t')[0].trim() }  // Split each line by tab and take the first column (file name)
        .set { file_path }          // Save the channel

    // Step 2: Process each log file and generate Parquet files
    def all_parquet_files = process_log_file(file_path)

    // Collect all parquet files into a single channel for analysis
    all_parquet_files
        .collect()                  // Collect all parquet files into a single list
        .set { parquet_file_list }  // Save the collected files as a new channel

    // Step 3: Analyze Parquet files
    analyze_parquet_files(parquet_file_list)

    // Debug: View individual outputs
    analyze_parquet_files.out.file_download_counts.view()
    analyze_parquet_files.out.summed_accession_counts.view()

    // Step 4: Generate Statistics for file downloads
    run_file_download_stat(analyze_parquet_files.out.all_data)

    // Step 5: Upload the JSON file
//     uploadJsonFile(summed_accession_counts) // TODO: Only testing purpose

}