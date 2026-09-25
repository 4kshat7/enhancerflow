process ROSE2 {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    
    container 'ghcr.io/khan-lab/rose:2.0.1'

    input:
    tuple val(meta), path(peaks), path(bam), path(bam_index), path(control_bam), path(control_index)
    val genome
    path custom_genome

    output:
    tuple val(meta), path("*/*_AllStitched.table.txt")  , emit: all_enhancers
    tuple val(meta), path("*/*_SuperStitched.table.txt"), emit: super_enhancers
    tuple val(meta), path("*/*_Plot_points.png")         , emit: plot
    // `rose2 main` runs rose2-geneMapper itself on both tables as its final
    // step, so these always exist. The file names come from
    // Path(table).stem + suffix, which is why *_withGENES carries `.table`
    // twice (e.g. foo_SuperStitched.table.table_withGENES.txt).
    tuple val(meta), path("*/*_SuperStitched.table_REGION_TO_GENE.txt")  , emit: super_region_to_gene
    tuple val(meta), path("*/*_SuperStitched.table_GENE_TO_REGION.txt")  , emit: super_gene_to_region
    tuple val(meta), path("*/*_SuperStitched.table.table_withGENES.txt") , emit: super_with_genes
    tuple val(meta), path("*/*_AllStitched.table_REGION_TO_GENE.txt")    , emit: all_region_to_gene
    tuple val(meta), path("*/*_AllStitched.table_GENE_TO_REGION.txt")    , emit: all_gene_to_region
    tuple val(meta), path("*/*_AllStitched.table.table_withGENES.txt")   , emit: all_with_genes
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
    // REPLACE -g, not accompany it. custom_genome is a staged path input, so
    // this renders a work-dir filename the container can actually see.
    def genome_arg = custom_genome
        ? "--custom ${custom_genome}"
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
    touch ${prefix}/${prefix}_SuperStitched.table_REGION_TO_GENE.txt
    touch ${prefix}/${prefix}_SuperStitched.table_GENE_TO_REGION.txt
    touch ${prefix}/${prefix}_SuperStitched.table.table_withGENES.txt
    touch ${prefix}/${prefix}_AllStitched.table_REGION_TO_GENE.txt
    touch ${prefix}/${prefix}_AllStitched.table_GENE_TO_REGION.txt
    touch ${prefix}/${prefix}_AllStitched.table.table_withGENES.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rose2: 1.0
    END_VERSIONS
    """
}
