for i in *.xml;
do
	prefix=$(echo $i | cut -d "." -f 1);
	num_error_lines=$(wc -l $prefix.prefrequency_probelist.part.error | cut -d " " -f 1);
	num_good_lines=$(wc -l $prefix.prefrequency_probelist.part | cut -d " " -f 1);
	if [ "$num_good_lines" != 0 ]; then
		echo -n "$prefix: "
		echo "scale=10; ($num_error_lines/$num_good_lines)*100" | bc
	fi
done
