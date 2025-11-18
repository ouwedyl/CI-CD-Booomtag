#!/bin/bash
echo "Building Lambda package..."
zip -r lambda_function.zip lambda_function.py
echo "lambda_function.zip created!"
