
#---- internal functions ----

.label_tile  <- function(tile, band, label_fn, output_dir, version, progress) {
    # Output file
    out_file <- .file_derived_name(
        tile = tile, band = band, version = version, output_dir = output_dir
    )
    # Resume feature
    if (file.exists(out_file)) {
        if (.check_messages()) {
            message("Recovery: tile '", tile[["tile"]], "' already exists.")
            message("(If you want to produce a new image, please ",
                    "change 'output_dir' or 'version' parameters)")
        }
        class_tile <- .tile_class_from_file(
            file = out_file, band = band, base_tile = tile
        )
        return(class_tile)
    }
    # Create chunks as jobs
    chunks <- .tile_chunks_create(tile = tile, overlap = 0)
    # Process jobs in parallel
    block_files <- .jobs_map_parallel_chr(chunks, function(chunk) {
        # Get job block
        block <- .block(chunk)
        # Output file name
        block_file <- .file_block_name(
            pattern = .file_pattern(out_file), block = block,
            output_dir = output_dir
        )
        # Resume processing in case of failure
        if (.raster_is_valid(block_file)) {
            return(block_file)
        }
        # Read and preprocess values
        values <- .tile_read_block(
            tile = tile, band = .tile_bands(tile), block = block
        )
        # Apply the labeling function to values
        values <- label_fn(values)
        # Prepare probability to be saved
        band_conf <- .conf_derived_band(
            derived_class = "class_cube", band = band
        )
        offset <- .offset(band_conf)
        if (.has(offset) && offset != 0) {
            values <- values - offset
        }
        scale <- .scale(band_conf)
        if (.has(scale) && scale != 1) {
            values <- values / scale
        }
        # Prepare and save results as raster
        .raster_write_block(
            files = block_file, block = block, bbox = .bbox(chunk),
            values = values, data_type = .data_type(band_conf),
            missing_value = .miss_value(band_conf),
            crop_block = NULL
        )
        # Free memory
        gc()
        # Returned value
        block_file
    }, progress = progress)
    # Merge blocks into a new class_cube tile
    class_tile <- .tile_class_merge_blocks(
        file = out_file, band = band, labels = .tile_labels(tile),
        base_tile = tile, block_files = block_files,
        multicores = .jobs_multicores()
    )
    # Return class tile
    class_tile
}

#---- label functions ----

.label_fn_majority <- function() {

    label_fn <- function(values) {
        # Used to check values (below)
        input_pixels <- nrow(values)
        values <- C_label_max_prob(values)
        # Are the results consistent with the data input?
        .check_processed_values(values, input_pixels)
        # Return values
        values
    }
    # Return closure
    label_fn
}
