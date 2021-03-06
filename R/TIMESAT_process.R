# devtools::load_all("/mnt/i/Research/phenology/rTIMESAT.R")
#' TIMESAT_process
#' @param d a data.frame with the columns of `t`, `y` and `w`
#' @export
TIMESAT_process <- function(d, nptperyear = 365, p_trs = 0.1, half_win = NULL, cache = FALSE) {
    if (is.null(half_win)) half_win = floor(nptperyear / 5 * 1)

    options <- list(
        ylu         = c(0, 9999), # Valid data range (lower upper)
        qc_1        = c(0.0, 0.2, 0.2), # Quality range 1 and weight
        qc_2        = c(0.2, 0.5, 0.5), # Quality range 2 and weight
        qc_3        = c(0.5, 1.0, 1), # Quality range 3 and weight
        A           = 0.1, # Amplitude cutoff value
        output_type = c(1, 1, 0), # Output files (1/0 1/0 1/0), 1: seasonality data; 2: smoothed time-series; 3: original time-series
        seasonpar   = 0.2, # Seasonality parameter (0-1)
        iters       = 2, # No. of envelope iterations (3/2/1)
        FUN         = 1, # Fitting method (1/2/3): (SG/AG/DL)
        half_win    = half_win, # half Window size for Sav-Gol.
        meth_pheno  = 1, # (1: seasonal amplitude, 2: absolute value, 3: relative amplitude, 4: STL trend)
        trs         = c(1, 1) * p_trs # Season start / end values
    )
    
    # data("MOD13A1")
    sitename <- "rTS"
    # sitename <- "CA-NS6"
    # d <- subset(MOD13A1$dt, date >= as.Date("2004-01-01") & date <= as.Date("2010-12-31") & site == sitename)
    dat = d
    if (nptperyear > 300) dat = d[format(t, "%m-%d") != "02-29"]
    # add one year data
    dat2 = dat
    dat2 = rbind(dat[1:nptperyear], dat) # the first year with no phenology info
    r <- TSF_main(
        y = dat2$y, qc = dat2$w, nptperyear,
        jobname = sitename, options, cache = cache, NULL)
    r$pheno %<>% dplyr::mutate(across(time_start:time_peak, function(x) {
        x  = x - nptperyear
        num2date(x, d$t)
    }))
    r$fit = data.table(t = d$t, z = r$fit$v1[-(1:nptperyear)])
    r
}

#' TIMESAT_plot
#' @importFrom lubridate make_date year
#' @import ggplot2
#' @export
TIMESAT_plot <- function(d, r, base_size = 12) {
    d_pheno  = r$pheno
    date_begin = d$t %>% first() %>% {make_date(year(.), 1, 1)}
    date_end   = d$t %>% last() %>% {make_date(year(.), 12, 31)}
    brks_year = seq(date_begin, date_end, by = "year")

    ggplot(d, aes(t, y)) +
        # geom_rect(data = d_ribbon, aes(x = NULL, y = NULL, xmin = xmin, xmax = xmax, group = I, fill = crop),
        #     ymin = -Inf, ymax = Inf, alpha = 0.2, show.legend = F) +
        geom_rect(data = d_pheno, aes(x = NULL, y = NULL, xmin = time_start, xmax = time_end, group = season),
            ymin = -Inf, ymax = Inf, alpha = 0.2, show.legend = F, linetype = 1,
            fill = alpha("grey", 0.2),
            color = alpha("grey", 0.4)) +
        geom_line(color = "black", size = 0.4) +
        geom_line(data = r$fit, aes(t, z), color = "purple") +
        geom_point(data = d_pheno, aes(time_start, val_start), color = "blue") +
        geom_point(data = d_pheno, aes(time_end, val_end), color = "blue") +
        geom_point(data = d_pheno, aes(time_peak, val_peak), color = "red") +
        geom_vline(xintercept = brks_year, color = "yellow3") +
        theme_bw(base_size = base_size) +
        theme(
            axis.text = element_text(color = "black"),
            panel.grid.minor = element_blank(),
            panel.grid.major = element_line(linetype = "dashed", size = 0.2)
        ) +
        scale_x_date(limits = c(date_begin, date_end), expand = c(0, 0))
}
