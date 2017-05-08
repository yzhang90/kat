# IMP-KAT Tests
# =============

# We'll use a simple testing harness in `bash` which just checks the output of
# `krun --search` against a supplied file. Run this with `bash runtests.sh`.

# SBC Benchmarking
# ----------------

# The above `compile` result for Collatz corresponds to the following K
# definition. We've replaced the `k` cells with constants, which can be done
# automatically using hashing but here is done manually.

# -   `INIT` corresponds to the entire program:
#     `int n , ( x , .Ids ) ; n = 782 ; x = 0 ; while ( 2 <= n ) { if ( n <= ( ( n / 2 ) * 2 ) ) { n = n / 2 ; } else { n = 3 * n + 1 ; } x = x + 1 ; }`
# -   `LOOP` corresponds to just the loop:
#     `while ( 2 <= n ) { if ( n <= ( ( n / 2 ) * 2 ) ) { n = n / 2 ; } else { n = 3 * n + 1 ; } x = x + 1 ; }`
# -   `FINISH` corresponds to the final state: `.`

# ### Concrete Execution Time

# First we'll demonstrate that execution time decreases drastically by running
# `collatz.imp` with the original semantics, and running `INIT` with the new
# semantics. Note that in both cases this is not as fast as an actual compiled
# definition could be because we're still using the strategy harness to control
# execution (which introduces overhead).


echo "Timing IMP Collatz concrete ..."
krun --directory '../' -cSTRATEGY='step until stuck?' collatz.imp
echo "Timing Compiled Collatz concrete ..."
krun --directory 'collatz-compiled/' -cSTRATEGY='step until stuck?' -cPGM='INIT'


# ### BIMC Execution Time

# In addition to concrete execution speedup, we get a speedup in the other
# analysis tools that can be run after SBC. Here we'll check the runtime of BIMC
# for the Collatz program, then compare to the time of BIMC of the system
# generated by SBC.

# To do this, we'll find the highest number that is reached on Collatz of 782 by
# incrementally increasing the maximum bound we check for as an invariant.


for bound in 1000 1174 1762 2644 3238 4858 7288 9323; do
    echo
    echo "Timing Collatz bimc with bound '$bound' ..."
    echo "Using concrete execution ..."
    krun --directory '../' -cSTRATEGY='step-with skip ; bimc 5000 (bexp? n <= '"$bound"')' collatz.imp

    echo "Using compiled execution ..."
    krun --directory 'collatz-compiled/' -cSTRATEGY='step-with skip ; bimc 5000 (bexp? n <= '"$bound"')' -cPGM='INIT'
done


# The first number is the `bound` on how high we'll let Collatz go. The second
# number is the number of steps it took to get there. The third number is how long
# it took to run on my laptop on a Sunday.

# 1.  1000 at 20 steps in 19s
# 2.  1174 at 40 steps in 22s
# 3.  1762 at 60 steps in ??s
# 4.  2644 at 730 steps in 2m34s
# 5.  3238 at 750 steps in 3m07s
# 6.  4858 at 770 steps in 3m44s
# 7.  7288 at 870 steps in 9m01s
# 8.  9232 at ??? steps in ?m??s