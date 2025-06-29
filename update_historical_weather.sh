#!/bin/sh

# making sure gdal path is correct
# FOR CEAB CLUSTER ONLY - TEMP OFF
# export PATH=/home/soft/gdal-2.3.2/bin/:$PATH
# export LD_LIBRARY_PATH=/home/soft/gdal-2.3.2/lib/:$LD_LIBRARY_PATH

# starting in project directory
cd ~/research/realtime-weather-spain

# pull in any pending commits
git pull origin main

# FOR CEAB CLUSTER ONLY - TEMP OFF
# /home/soft/R-4.1.0/bin/R CMD BATCH --no-save --no-restore code/get_historical_data.R logs/get_historical_data.out 
R CMD BATCH --no-save --no-restore code/get_historical_data.R logs/get_historical_data.out 

# Commit and push the log files from this latest run
git add --all
git commit -m 'new data and log files (cluster - automated)'
git pull origin main
git push origin main

# run using:
# qsub -q ceab -pe make 1 -l h_vmem=8G -m bea -M johnrbpalmer@gmail.com ~/research/realtime-weather-spain/update_historical_weather.sh
