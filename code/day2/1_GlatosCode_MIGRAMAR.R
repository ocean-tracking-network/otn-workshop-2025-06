# 07 - Introduction to glatos ####

## Set your working directory

setwd("YOUR/PATH/TO/data/migramar")
library(glatos)
library(tidyverse)
library(lubridate)

# First we need to create one detections file from all our detection extracts.
library(utils)

format <- cols( # Heres a col spec to use when reading in the files
  .default = col_character(),
  datelastmodified = col_date(format = ""),
  bottom_depth = col_double(),
  receiver_depth = col_double(),
  sensorname = col_character(),
  sensorraw = col_character(),
  sensorvalue = col_character(),
  sensorunit = col_character(),
  datecollected = col_datetime(format = ""),
  longitude = col_double(),
  latitude = col_double(),
  yearcollected = col_double(),
  monthcollected = col_double(),
  daycollected = col_double(),
  julianday = col_double(),
  timeofday = col_double(),
  datereleasedtagger = col_logical(),
  datereleasedpublic = col_logical()
)
detections <- tibble()
for (detfile in list.files('.', full.names = TRUE, pattern = "gmr_matched.*\\.csv")) {
  print(detfile)
  tmp_dets <- read_csv(detfile, col_types = format)
  detections <- bind_rows(detections, tmp_dets)
}
write_csv(detections, 'all_dets.csv', append = FALSE)


## glatos help files are helpful!!
?read_otn_deployments

# Save our detections file data into a dataframe called detections
detections <- read_otn_detections('all_dets.csv')


# View first 2 rows of output
head(detections, 2)

## Filtering False Detections ####
## ?glatos::false_detections

# write the filtered data (no rows deleted, just a filter column added)
# to a new det_filtered object
detections_filtered <- false_detections(detections, tf=3600, show_plot=TRUE)
head(detections_filtered)
nrow(detections_filtered)


# Filter based on the column if you're happy with it.
detections_filtered <- detections_filtered[detections_filtered$passed_filter == 1,]
nrow(detections_filtered) # Smaller than before


# Summarize Detections ####
# ?summarize_detections
# summarize_detections(detections_filtered)

# By animal ====

sum_animal <- summarize_detections(detections_filtered, location_col = 'station', summ_type='animal')

sum_animal


# By location ====

sum_location <- summarize_detections(detections_filtered, location_col = 'station', summ_type='location')

head(sum_location)


# You can make your own column and use that as the location_col
# For example we will create a uniq_station column for if you have duplicate station names across projects

detections_filtered_special <- detections_filtered %>%
  mutate(station_uniq = paste(glatos_receiver_project, station, sep=':'))


sum_location_special <- summarize_detections(detections_filtered_special, location_col = 'station_uniq', summ_type='location')

head(sum_location_special)


# By both dimensions
sum_animal_location <- summarize_detections(det = detections_filtered,
                                            location_col = 'station',
                                            summ_type='both')

head(sum_animal_location)


# Filter out stations where the animal was NOT detected.
sum_animal_location <- sum_animal_location %>% filter(num_dets > 0)

sum_animal_location


# Create a custom vector of Animal IDs to pass to the summary function
# look only for these ids when doing your summary
tagged_fish <- c('GMR-11159-2016-12-12', 'GMR-25720-2014-01-18')

sum_animal_custom <- summarize_detections(det=detections_filtered,
                                          animals=tagged_fish,  # Supply the vector to the function
                                          location_col = 'station',
                                          summ_type='animal')

sum_animal_custom


# Reduce Detections to Detection Events ####

# ?glatos::detection_events
# arrival and departure time instead of multiple detection rows
# you specify how long an animal must be absent before starting a fresh event

events <- detection_events(detections_filtered,
                           location_col = 'station',
                           time_sep=3600)

head(events)


# keep detections, but add a 'group' column for each event group
detections_w_events <- detection_events(detections_filtered,
                                        location_col = 'station',
                                        time_sep=3600, condense=FALSE)

# 08 - More Features of glatos ####


?residence_index

#Using all the events data will take too long, we will subset to just use a couple animals
events %>% group_by(animal_id) %>% summarise(count=n()) %>% arrange(desc(count))

subset_animals <- c('GMR-25724-2014-01-22', 'GMR-25718-2014-01-17', 'GMR-25720-2014-01-18')
events_subset <- events %>% filter(animal_id %in% subset_animals)

events_subset
# Calc residence index using the Kessel method
rik_data <- residence_index(events_subset,
                            calculation_method = 'kessel')
rik_data


# Calc residence index using the time interval method, interval set to 6 hours
# "Kessel" method is a special case of "time_interval" where time_interval_size = "1 day"

rit_data <- residence_index(events_subset,
                            calculation_method = 'time_interval',
                            time_interval_size = "6 hours")
rit_data

# BREAK

# 9 - Basic Visualization and Plotting

# Visualizing Data - Abacus Plots ####
# ?glatos::abacus_plot
# customizable version of the standard VUE-derived abacus plots

abacus_plot(detections_w_events,
            location_col='station',
            main='MIGRAMAR Detections by Station') # can use plot() variables here, they get passed thru to plot()

# pick a single fish to plot
abacus_plot(detections_filtered[detections_filtered$animal_id== "GMR-25724-2014-01-22",],
            location_col='station',
            main="GMR-25724-2014-01-22 Detections By Station")

# Bubble Plots for Spatial Distribution of Fish ####
# bubble variable gets the summary data that was created to make the plot
detections_filtered

?detection_bubble_plot

# We'll use raster to get a polygon to plot against
library(raster)
ECU <- getData('GADM', country="Ecuador", level=1)
GAL <- ECU[ECU$NAME_1=="Galápagos",]

bubble_station <- detection_bubble_plot(detections_filtered,
                                        background_ylim = c(-2, 2),
                                        background_xlim = c(-93.5, -89),
                                        map = GAL,
                                        location_col = 'station',
                                        out_file = 'migramar_bubbles_by_stations.png')
bubble_station

# Challenge 1 ----
# Create a bubble plot of the area on which we zoomed in earlier. Set the bounding box using the provided nw + se cordinates, change the colour scale and
# resize the points to be smaller. As a bonus, add points for the other receivers that don't have any detections.
# Hint: ?detection_bubble_plot will help a lot
# Here's some code to get you started

nw <- c(-2, -89)
se <- c(2, -93.5)
