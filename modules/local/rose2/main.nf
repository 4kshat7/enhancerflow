process ROSE2 {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    
    container 'ghcr.io/khan-lab/rose:2.0.1'

    input:
    tuple val(meta), path(peaks), path(bam), path(bam_index), path(control_bam), path(control_index)
    val genome

    output:
    tuple val(meta), path("*/*_AllStitched.table.txt")  , emit: all_enhancers
    tuple val(meta), path("*/*_SuperStitched.table.txt"), emit: super_enhancers
    tuple val(meta), path("*/*_Plot_points.png")         , emit: plot
    path "versions.yml"                                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def control = control_bam && control_bam.name != 'NO_FILE' ? "-c ${control_bam}" : ""
    def stitch = params.stitch_distance ?: 12500
    def tss = params.tss_exclusion ?: 2500
    // rose2 puts -g/--genome and --custom in an argparse mutually-exclusive
    // group, and -g only accepts {MM8,MM9,MM10,HG18,HG19,HG38}. For an
    // assembly with no built-in annotation (e.g. T2T-CHM13) --custom must
    // REPLACE -g, not accompany it.
    def genome_arg = params.custom_genome
        ? "--custom ${params.custom_genome}"
        : "-g ${genome.toString().toUpperCase()}"

    """
    rose2 main ${genome_arg} \\
        -i ${peaks} \\
        -r ${bam} \\
         ${control} \\
        -o ${prefix} \\
        --tss ${tss} \\
        --stitch ${stitch} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rose2: \$(echo "1.0")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}
    touch ${prefix}/${prefix}_AllStitched.table.txt
    touch ${prefix}/${prefix}_SuperStitched.table.txt
    touch ${prefix}/${prefix}_Plot_points.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rose2: 1.0
    END_VERSIONS
    """
}
