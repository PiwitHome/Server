#!/bin/sh

echo "Enter your username:"
read username

if [ "$username" = "blessen" ]
then
	echo 'Success!!! You are now logged in.'
else
	echo 'Sorry, wrong username.'
fi