#!/bin/bash

case a$1 in
	(a-htm)
		echo "<h2>Last scan</h2>"
		echo "<p>"
		date
		echo "</p>"
		;;
	(*)
		date
esac
