wbgt_domain_cases <- function(n = 180L) {
  tas <- c(-20, 0, 20, 35, 50)
  dewpoint_delta <- c(0, 1, 10, 30)
  wind <- c(0, 0.05, 0.1, 1, 5, 20)
  radiation <- c(0, 5, 15, 100, 500, 900, 1200)
  zenith <- c(0, 30, 60, 87, 88, 90, 95)
  pressure <- c(700, 850, 1010, 1050)
  albedo <- c(0, 0.4, 1)
  direct <- c(0, 0.8, 1)
  index <- seq_len(n) - 1L
  data.frame(
    tas = tas[index %% length(tas) + 1L],
    dewp = tas[index %% length(tas) + 1L] -
      dewpoint_delta[(index * 3L + 1L) %% length(dewpoint_delta) + 1L],
    wind = wind[(index * 5L + 2L) %% length(wind) + 1L],
    radiation = radiation[(index * 7L + 3L) %% length(radiation) + 1L],
    zenith = HeatStress:::degToRad(zenith[(index * 11L + 5L) %% length(zenith) + 1L]),
    Pair = pressure[(index * 13L + 7L) %% length(pressure) + 1L],
    SurfAlbedo = albedo[(index * 17L + 11L) %% length(albedo) + 1L],
    propDirect = direct[(index * 19L + 13L) %% length(direct) + 1L],
    irad = index %% 2L,
    stringsAsFactors = FALSE
  )
}
