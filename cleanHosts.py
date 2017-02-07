#!/usr/bin/python
#-------------------------------------------------------------
# IBM Confidential
# OCO Source Materials
# (C) Copyright IBM Corp. 2010, 2015
# The source code for this program is not published or 
# otherwise divested of its trade secrets, irrespective of 
# what has been deposited with the U.S. Copyright Office.
#-------------------------------------------------------------

import random
import string
import sys, getopt
import argparse
import os
import subprocess
import threading
import time
import multiprocessing

def get_args():
  global partialCleanup
  '''This function parses and return arguments passed in'''
  # Assign description to the help doc
  parser = argparse.ArgumentParser(
    description='BigInsights Docker Cleanup Script')
  parser.add_argument(
    'input', metavar='[filename]', type=str, help='hosts text file, containg list of hostnames separated by new line.')
  parser.add_argument('-p', "--partial", action="store_true", help='Partial Cleanup.')

  # Array for all arguments passed to script
  args = parser.parse_args()
  try:
    fname = args.input
    partialCleanup = False
    if args.partial:
      partialCleanup = True
  except:
    parser.print_help()
 
  # Return all variable values
  return fname

# Match return values from get_arguments()
# and assign to their respective variables
fname = get_args()

# Print the values
print "\nHosts file name: [ %s ]\n" % fname
filename_array = []
name_array = []
image_name = "iop-m"
containError = False

with open(fname) as my_file:
  filename_array= my_file.readlines()

name_array = [item.strip() for item in filename_array]

def cleanHost(host):
  # Get containers
  proc = subprocess.Popen(["ssh " + host + " docker ps -a | grep " + image_name + " | awk '{print $NF}'"], stdout=subprocess.PIPE, shell=True)
  (conts, err) = proc.communicate()
  if err is not None:
    containError = True
    print(host + ": Error determining existing docker containers: " + str(err))


  if conts != "":
    conts = conts.replace('\n',' ').replace('\r','')

    # Stop container
    proc = subprocess.Popen(["ssh " + host + " docker stop " + conts], stdout=subprocess.PIPE, shell=True)
    (out, err) = proc.communicate()
    retCode = proc.returncode
    if retCode == 0:
      print(host + ": Stopped container " + conts.replace('\n',' ').replace('\r',''))
    else:
      containError = True
      print(host + ": Stopping container " + conts.replace('\n',' ').replace('\r','') + " failed with exit code " + retCode + str(err))

    # Remove container
    proc = subprocess.Popen(["ssh " + host + " docker rm " + conts], stdout=subprocess.PIPE, shell=True)
    (out, err) = proc.communicate()
    retCode = proc.returncode
    if retCode == 0:
      print(host + ": Removed container " + conts.replace('\n',' ').replace('\r',''))
    else:
      containError = True
      print(host + ": Removing container " + conts.replace('\n',' ').replace('\r','') + " failed with exit code " + retCode + " and error " + str(err))

  if partialCleanup:
    print(host + ": Partial cleanup is selected. Skipping removal of image and files.")
  else:
    # Check existing image
    proc = subprocess.Popen(["ssh " + host + " docker images | grep " + image_name + " | awk '{print $3}'"], stdout=subprocess.PIPE, shell=True)
    (image, err) = proc.communicate()
    if err is not None:
      print(host + ": Error determining existing docker image: " , err)

    if image != "":
      # Remove Image
      proc = subprocess.Popen(["ssh " + host + " docker rmi " + image_name], stdout=subprocess.PIPE, shell=True)
      (out, err) = proc.communicate()
      retCode = proc.returncode
      if retCode == 0:
        print(host + ": Removed image " + image_name)
      else:
        containError = True
        print(host + ": Removing image " + image_name + " failed with exit code " + retCode + " and error " + str(err))

    # Remove files
    retCode=os.system("ssh " + host + " rm -f /tmp/" + image_name + ".tar /tmp/run.sh")
    if retCode == 0:
      print(host + ": Cleaned up files (run.sh and " + image_name + ".tar)")

if __name__ == '__main__':
  print("start time: "+time.ctime())
  pool = multiprocessing.Pool(processes=10)
  print("Cleanup process is going to stop docker containers related to " + image_name + ", remove them and remove " + image_name + " docker image on following hosts:")
  print(name_array)
  pool.map_async(cleanHost, name_array)
  pool.close()
  pool.join()
  if containError:
    print("\nThere were errors during cleanup.\n")
  else:
    print("\nCleanup is successful.\n")
  print("End time: "+time.ctime())
