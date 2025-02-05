
#' @title Apply a function to one band of a time series
#' @name .apply
#' @keywords internal
#' @noRd
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#'
#' @param  data      Tibble.
#' @param  col       Column where function should be applied
#' @param  fn        Function to be applied.
#' @return           Tibble where function has been applied.
.apply <- function(data, col, fn, ...) {
    # pre-condition
    .check_chr_within(col,
                      within = names(data),
                      msg = "invalid column name"
    )
    # select data do unpack
    x <- data[col]
    # prepare to unpack
    x[["#.."]] <- seq_len(nrow(data))
    # unpack
    x <- tidyr::unnest(x, cols = dplyr::all_of(col))
    x <- dplyr::group_by(x, .data[["#.."]])
    # apply user function
    x <- fn(x, ...)
    # pack
    x <- dplyr::ungroup(x)
    x <- tidyr::nest(x, `..unnest_col` = -"#..")
    # remove garbage
    x[["#.."]] <- NULL
    names(x) <- col
    # prepare result
    data[[col]] <- x[[col]]
    return(data)
}

.apply_feature <- function(feature, block, window_size, expr,
                           out_band, in_bands, overlap, output_dir) {
    # Output file
    out_file <- .file_eo_name(
        tile = feature, band = out_band,
        date = .tile_start_date(feature), output_dir = output_dir
    )
    # Resume feature
    if (.raster_is_valid(out_file, output_dir = output_dir)) {
        # # Callback final tile classification
        # .callback(process = "Apply", event = "recovery",
        #           context = environment())
        if (.check_messages()) {
            message("Recovery: band ",
                    paste0("'", out_band, "'", collapse = ", "),
                    " already exists.")
            message("(If you want to produce a new image, please ",
                    "change 'output_dir' or 'version' parameters)")
        }

        # Create tile based on template
        feature <- .tile_eo_from_files(
            files = out_file, fid = .fi_fid(.fi(feature)),
            bands = out_band, date = .tile_start_date(feature),
            base_tile = feature, update_bbox = FALSE
        )
        return(feature)
    }
    # Remove remaining incomplete fractions files
    unlink(out_file)
    # Create chunks as jobs
    chunks <- .tile_chunks_create(
        tile = feature, overlap = overlap, block = block
    )
    # Process jobs sequentially
    block_files <- .jobs_map_sequential(chunks, function(chunk) {
        # Get job block
        block <- .block(chunk)
        # Block file name for each fraction
        block_files <- .file_block_name(
            pattern = .file_pattern(out_file), block = block,
            output_dir = output_dir
        )
        # Resume processing in case of failure
        if (.raster_is_valid(block_files)) {
            return(block_files)
        }
        # Read bands data
        values <- .apply_data_read(
            tile = feature, block = block, in_bands = in_bands
        )
        # Evaluate expression here
        # Band and kernel evaluation
        values <- eval(
            expr = expr[[out_band]],
            envir = values,
            enclos = .kern_functions(
                window_size = window_size,
                img_nrow = block[["nrows"]],
                img_ncol = block[["ncols"]]
            )
        )
        # Prepare fractions to be saved
        band_conf <- .tile_band_conf(tile = feature, band = out_band)
        offset <- .offset(band_conf)
        if (.has(offset) && offset != 0) {
            values <- values - offset
        }
        scale <- .scale(band_conf)
        if (.has(scale) && scale != 1) {
            values <- values / scale
        }
        # Job crop block
        crop_block <- .block(.chunks_no_overlap(chunk))
        # Prepare and save results as raster
        .raster_write_block(
            files = block_files, block = block, bbox = .bbox(chunk),
            values = values, data_type = .data_type(band_conf),
            missing_value = .miss_value(band_conf),
            crop_block = crop_block
        )
        # Free memory
        gc()
        # Returned block files for each fraction
        block_files
    })
    # Merge blocks into a new class_cube tile
    band_tile <- .tile_eo_merge_blocks(
        files = out_file, bands = out_band, base_tile = feature,
        block_files = block_files, multicores = 1, update_bbox = FALSE
    )
    # Return a feature tile
    band_tile
}

.apply_data_read <- function(tile, block, in_bands) {
    # for cubes that have a time limit to expire - mpc cubes only
    tile <- .cube_token_generator(tile)
    # Read and preprocess values from cloud
    # Get cloud values (NULL if not exists)
    cloud_mask <- .tile_cloud_read_block(tile = tile, block = block)
    # Read and preprocess values from each band
    values <- purrr::map_dfc(in_bands, function(band) {
        # Get band values
        values <- .tile_read_block(tile = tile, band = band, block = block)
        # Remove cloud masked pixels
        if (.has(cloud_mask)) {
            values[cloud_mask] <- NA
        }
        # Return values
        as.data.frame(values)
    })
    # Set columns name
    colnames(values) <- in_bands
    # Return values
    values
}

#' @title Apply an expression across all bands
#'
#' @name .apply_across
#' @keywords internal
#' @noRd
#'
#' @param data  Tile name.
#'
#' @return      A sits tibble with all processed bands.
#'
.apply_across <- function(data, fn, ...) {

    # Pre-conditions
    .check_samples(data)

    result <-
        .apply(data, col = "time_series", fn = function(x, ...) {
            dplyr::mutate(x, dplyr::across(
                dplyr::matches(sits_bands(data)),
                fn, ...
            ))
        }, ...)

    return(result)
}

#' @title Captures a band expression
#'
#' @name .apply_capture_expression
#' @keywords internal
#' @noRd
#'
#' @param tile_name  Tile name.
#'
#' @return           Named list with one expression
#'
.apply_capture_expression <- function(...) {
    # Capture dots as a list of quoted expressions
    list_expr <- lapply(substitute(list(...), env = environment()),
                        unlist,
                        recursive = FALSE)[-1]

    # Check bands names from expression
    .check_expression(list_expr)

    # Get out band
    out_band <- toupper(gsub("_", "-", names(list_expr)))
    names(list_expr) <- out_band

    return(list_expr)
}

#' @title Finds out all existing bands in an expression
#'
#' @name .apply_input_bands
#' @keywords internal
#' @noRd
#'
#' @param tile       Data cube tile.
#' @param expr       Band expression.
#'
#' @return           List of combination among tiles, bands, and dates
#'                   that are missing from the cube.
#'
.apply_input_bands <- function(cube, expr) {

    # Get all required bands in expression
    expr_bands <- toupper(.apply_get_all_names(expr[[1]]))

    # Get all input bands in cube data
    bands <- .cube_bands(cube)

    # Select bands that are in input expression
    bands <- bands[bands %in% expr_bands]

    # Found bands
    found_bands <- expr_bands %in% bands

    # Post-condition
    .check_that(
        x = all(found_bands),
        local_msg = "use 'sits_bands()' to check available bands",
        msg = paste("band(s)", paste0("'", expr_bands[!found_bands],
                                      "'", collapse = ", "), "not found")
    )

    return(bands)
}

#' @title Returns all names in an expression
#'
#' @name .apply_get_all_names
#' @keywords internal
#' @noRd
#' @param expr       Expression.
#'
#' @return           Character vector with all names in expression.
#'
.apply_get_all_names <- function(expr) {
    if (is.call(expr)) {
        unique(unlist(lapply(as.list(expr)[-1], .apply_get_all_names)))
    } else if (is.name(expr)) {
        paste0(expr)
    } else {
        character()
    }
}

.kern_functions <- function(window_size, img_nrow, img_ncol) {

    # Pre-conditions
    .check_window_size(window_size, max = min(img_nrow, img_ncol) - 1)

    result_env <- list2env(list(
        w_median = function(m) {
            C_kernel_median(
                x = as.matrix(m), ncols = img_ncol, nrows = img_nrow,
                band = 0, window_size = window_size
            )
        },
        w_mean = function(m) {
            C_kernel_mean(
                x = as.matrix(m), ncols = img_ncol, nrows = img_nrow,
                band = 0, window_size = window_size
            )
        },
        w_sd = function(m) {
            C_kernel_sd(
                x = as.matrix(m), ncols = img_ncol, nrows = img_nrow,
                band = 0, window_size = window_size
            )
        },
        w_min = function(m) {
            C_kernel_min(
                x = as.matrix(m), ncols = img_ncol, nrows = img_nrow,
                band = 0, window_size = window_size
            )
        },
        w_max = function(m) {
            C_kernel_max(
                x = as.matrix(m), ncols = img_ncol, nrows = img_nrow,
                band = 0, window_size = window_size
            )
        }
    ), parent = parent.env(environment()), hash = TRUE)

    return(result_env)
}
