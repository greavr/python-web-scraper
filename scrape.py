############
# Simple script to download specific files from a page
# Validates that file not downloaded already
###########


import urllib2
import urllib
import lxml.html
from os import path
import sys


def main():

    if len(sys.argv) == 3:
        urlToScrape = sys.argv[1]
        fileType = sys.argv[2].split(',')
    else:
        print("This function scrapes a page to download all files of a specific type from specified page")
        print("Please provide two arguements, url to scrape, and file type to pull, comma seperated")
        print("Example: python scrape.py https://somepage.com/ jpeg,png,zip")
        quit()

    # Get list of files
    print("Scraping page " + urlToScrape + " for the following file types:" + ' '.join(fileType))
    FileList = GetFiles(urlToScrape,fileType)
    size = len(FileList)
    print("Found " +  str(size) + " files to download.")

    # Download files
    i = 0
    for aFile in FileList:
        downloadfile(aFile)
        print(str(i) + " of " + str(size))
        i += 1

def GetFiles(url,filestypes):
    # Parse site
    connection = urllib.urlopen(url)
    dom =  lxml.html.fromstring(connection.read())

    #Results Array
    results = []
    for link in dom.xpath('//a/@href'):
        # Itterate over file filestypes
        for aType in filestypes:
            if link.find("." + aType) != -1:
                results.append(url + link)

    #Return Results
    return results

def downloadfile(fileurl):
    #download the file if not already exists
    filename = fileurl.split("/")[-1]

    if not path.exists(filename):
        #Download File
        print('Downloading: ' + filename)
        urllib.urlretrieve(fileurl, filename)
    else:
        print ('File ' + filename + ' found, skipping')


if __name__== "__main__":
  main()
