#!/bin/bash

set -e 

# Script to generate PDF files from *.ipynb notebook in the workshop directory
jupyter nbconvert --to pdf *.ipynb
