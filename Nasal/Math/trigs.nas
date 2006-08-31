# ********** ********** ********** ********** ********** ********** ********** ********** ********** **********
# Copyright (C) 2005  Ampere K. [Hardraade]
#
# This file is protected by the GNU Public License.  For more details, please see the text file COPYING.
# ********** ********** ********** ********** ********** ********** ********** ********** ********** **********
# trigs.nas
# This nasal script extends the existing trignometric functions by adding arcsin, and arccos.
#
# Class:
#  Math
#	 Methods:
#	  arccos(x)	- returns arccos(x), with -1 < x < 1.
#	  arcsin(x)	- returns arcsin(x), with -1 < x < 1.
# ********** ********** ********** ********** ********** ********** ********** ********** ********** **********

# Returns arccos(x), with -1 < x < 1.
math.arccos = func(x){
	return (3.141592654/2 - math.arcsin(x));
}

# Returns arcsin(x), with -1 < x < 1.
math.arcsin = func(x){
	# Find arcsin(x) by first doing a table look-up, then interopolate the value of the desire point using
	#  integration.  Accuracy could be achieved up to the 8th decimal place if necessary.
	
	factor = 1;
	power = math.pow(10, 6);	# Accuracy up to the nth decimal place.
	precision = math.pow(power, -1);
	tableSize = 100;		# Size of the look-up table.
	
	# Negative and positive angles yield the same result, only the signs are different.
	if (x < 0){
		factor = -1;
		x = x * factor;
	}
	
	# Look-up table for every 1.8 degrees, for a total of 180 degrees.
	table = [0,
		0.010000167, 0.020001334, 0.030004502, 0.040010674, 0.050020857,
		0.060036058, 0.070057293, 0.080085580, 0.090121945, 0.100167421,
		0.110223050, 0.120289882, 0.130368980, 0.140461415, 0.150568273,
		0.160690653, 0.170829669, 0.180986451, 0.191162147, 0.201357921,
		0.211574960, 0.221814470, 0.232077683, 0.242365851, 0.252680255,
		0.263022203, 0.273393031, 0.283794109, 0.294226838, 0.304692654,
		0.315193032, 0.325729487, 0.336303575, 0.346916898, 0.357571104,
		0.368267893, 0.379009021, 0.389796296, 0.400631593, 0.411516846,
		0.422454062, 0.433445320, 0.444492777, 0.455598673, 0.466765339,
		0.477995199, 0.489290778, 0.500654712, 0.512089753, 0.523598776,
		0.535184790, 0.546850951, 0.558600565, 0.570437109, 0.582364238,
		0.594385800, 0.606505855, 0.618728691, 0.631058841, 0.643501109,
		0.656060591, 0.668742703, 0.681553212, 0.694498266, 0.707584437,
		0.720818761, 0.734208787, 0.747762635, 0.761489053, 0.775397497,
		0.789498209, 0.803802319, 0.818321951, 0.833070358, 0.848062079,
		0.863313115, 0.878841152, 0.894665817, 0.910808997, 0.927295218,
		0.944152115, 0.961411019, 0.979107684, 0.997283222, 1.015985294,
		1.035269672, 1.055202321, 1.075862200, 1.097345170, 1.119769515,
		1.143284062, 1.168080485, 1.194412844, 1.222630306, 1.253235898,
		1.287002218, 1.325230809, 1.370461484, 1.429256853, 1.570796327];
		
	intPart = int(x * tableSize + 0.5);
	decPart = (x * tableSize - intPart) / tableSize ;
	
	area = 0;
	# Perform integration to calculate arcsin(x).
	# Positive case:
	for(i = intPart/tableSize; i < intPart/tableSize + decPart; i = i + precision){
		# Calculate the area of a trapezoid.
		a = 1 / math.sqrt(1 - math.pow(i, 2));
		b = 1 / math.sqrt(1 - math.pow(i + precision, 2));
		
		area = area + a + b;
	}
	# Negative case:
	for(i = (intPart - precision) / tableSize; i > intPart/tableSize + decPart; i = i - precision){
		# Calculate the area of a trapezoid.
		a = 1 / math.sqrt(1 - math.pow(i - precision, 2));
		b = 1 / math.sqrt(1 - math.pow(i, 2));
		
		area = area - a - b;
	}
	
	return ((table[intPart] + int(area + 0.5) * precision / 2) * factor);
}