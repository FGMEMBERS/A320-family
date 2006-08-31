# ********** ********** ********** ********** ********** ********** ********** ********** ********** **********
# Copyright (C) 2005  Ampere K. [Hardraade]
#
# This file is protected by the GNU Public License.  For more details, please see the text file COPYING.
# ********** ********** ********** ********** ********** ********** ********** ********** ********** **********
# generic.nas
# This nasal script extends the existing mathematical functions in Nasal.
#
# Class:
#  Math
#	 Methods:
#	  abs(x)	- returns the absolute value of x.
#	  factorial(n)	- returns the factorial of n.
#	  pow(x, n)	- raises and returns x by power of n.
# ********** ********** ********** ********** ********** ********** ********** ********** ********** **********

# Returns the absolute value of x.
math.abs = func(x){
	if (x < 0){
		return (x * -1);
	}
	return x;
}

# Returns the factorial of n.
math.factorial = func(n){
	if (n < 0){
		msg = "Invalid value in factorial(n). \n";
		msg = msg ~ "\t Reason: n cannot be a negative number.";
		die (msg);
	}
	elsif (n == 0){
		return 1;
	}
	
	result = 1;
	for (i = 0; i < n - 1; i = i + 1){
		result = result * (n - i);
	}
	return result;
}

# Returns x to the power of n.
math.pow = func(x, n){
	return math.exp(n * math.ln(x));
}
