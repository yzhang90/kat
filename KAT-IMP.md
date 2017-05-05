IMP Language
============

The IMP language is largely defined as in the [K tutorial](www.kframework.org/index.php/K_Tutorial).
Refer there for a more detailed explanation of the language.

Configuration
-------------

The IMP language has a `k` cell for execution and a `mem` cell for storage.
In IMP, base values are of sorts `Int` and `Bool`.

```{.k .imp-lang}
module IMP
  imports MAP
  imports STRATEGY

  configuration <imp>
                  <k> $PGM:Stmt </k>
                  <mem> .Map </mem>
                </imp>

  syntax KResult  ::= Int | Bool
```

Expressions
-----------

IMP has `AExp` for arithmetic expressions (over integers).

```{.k .imp-lang}
  syntax AExp  ::= Int | Id
                 | AExp "/" AExp [left, strict]
                 > AExp "+" AExp [left, strict]
                 | "(" AExp ")"  [bracket]
//----------------------------------------
  rule I1 / I2 => I1 /Int I2  requires I2 =/=Int 0 [structural]
  rule I1 + I2 => I1 +Int I2                       [structural]
```

IMP has `BExp` for boolean expressions.

```{.k .imp-lang}
  syntax BExp  ::= Bool
                 | AExp "<=" AExp [seqstrict, latex({#1}\leq{#2})]
                 | "!" BExp       [strict]
                 > BExp "&&" BExp [left, strict(1)]
                 | "(" BExp ")"   [bracket]
//-----------------------------------------
  rule I1 <= I2   => I1 <=Int I2 [structural]
  rule ! T        => notBool T   [structural]
  rule true  && B => B           [structural]
  rule false && _ => false       [structural]
```

Statements
----------

IMP has `{_}` for creating blocks, `if_then_else_` for choice, `_:=_` for assignment, and `while(_)_` for looping.

```{.k .imp-lang}
  syntax Block ::= "{" "}"
                 | "{" Stmt "}"

  syntax Ids ::= List{Id,","}

  syntax Stmt  ::= Block
                 | "int" Ids ";"
                 | Id "=" AExp ";"                      [strict(2)]
                 | "if" "(" BExp ")" Block "else" Block [strict(1)]
                 | "while" "(" BExp ")" Block
                 > Stmt Stmt                            [left]
//------------------------------------------------------------
  rule {}              => .        [structural]
  rule {S}             => S        [structural]

  rule int .Ids ;      => .        [structural]
  rule S1:Stmt S2:Stmt => S1 ~> S2 [structural]

  rule <k> int (X,Xs => Xs) ; ... </k> <mem> Rho:Map (.Map => X |-> ?V:Int) </mem> requires notBool (X in keys(Rho)) [structural]
```

Semantics
---------

All the rules above are "regular" rules, not to be considered transition steps by analysis tools.
The rules below are named (with the attribute `tag`) so that strategy-based analysis tools can treat them specially.

```{.k .imp-lang}
  rule <k> X:Id        => I ... </k> <mem> ... X |-> I        ... </mem> [tag(lookup)]
  rule <k> X = I:Int ; => . ... </k> <mem> ... X |-> (_ => I) ... </mem> [tag(assignment)]

  rule if (true)  B:Block else _ => B:Block [tag(if), transition]
  rule if (false) _ else B:Block => B:Block [tag(if), transition]

  rule while (B) STMT => if (B) {STMT while (B) STMT} else {} [tag(while)]
endmodule
```

Instantiation of KAT
====================

The KAT requires some programming-language specific information to work.
Instantiation of the progamming language to KAT should happen with the language semantics on an as-needed basis.

The module `IMP-KAT` includes all the supported analysis for the IMP language.

```{.k .imp-kat}
requires "imp.k"
requires "kat.k"

module IMP-ANALYSIS
  imports IMP-BIMC
  imports IMP-SBC
endmodule

module IMP-KAT
  imports IMP
  imports KAT
```

### Define `push` and `pop`

Here the definition of a `State` for IMP is given, as well as the definitions of how to `push` and `pop` states.

```{.k .imp-kat}
  syntax State ::= "{" K "|" Map "}"
//----------------------------------
  rule <s> push                => push { KCELL | MEM } ... </s> <imp> <k> KCELL      </k> <mem> MEM      </mem> </imp> [structural]
  rule <s> pop { KCELL | MEM } => .                    ... </s> <imp> <k> _ => KCELL </k> <mem> _ => MEM </mem> </imp> [structural]
```

### Define `#step`

```{.k .imp-kat}
  rule <s> #step => ^ lookup | ^ assignment | ^ while | ^ if ... </s> [structural]
```

### Define `bool?`

```{.k .imp-kat}
  rule <s> bool? [ { true  | _ } ] => #true  ... </s> [structural]
  rule <s> bool? [ { false | _ } ] => #false ... </s> [structural]
endmodule
```

BIMC
----

Here we provide a way to make queries about the current IMP memory using IMP's `BExp` sort directly.

-   `bexp?` is a predicate that allows us to make queries about the current execution memory.

```{.k .imp-kat}
module IMP-BIMC
  imports IMP-KAT
  imports KAT-BIMC

  syntax StatePred ::= "bexp?" BExp
//---------------------------------
  rule <s> bexp? B [ { _ | MEM } ] => pop { B | MEM } ; eval ... </s> [structural]
endmodule
```

### Example (Invariant Failure)

Here we check the property `x <= 7` for 5 steps of execution after the code has initialized (the `step` in front of the command).
Run this with `krun --search bimc.imp`.

```{.imp .bimc .k}
int x ;
x = 0 ;
x = x + 15 ;
```

### Example (Bound Reached)

### Example (Execution Terminates)

SBC
---

```{.k .imp-kat}
module IMP-SBC
  imports IMP-KAT
  imports KAT-SBC
```

### Define `cut-point?`

IMP will have a cut-point at the beginning of every `while` loop, allowing every execution of IMP to terminate.

```{.k .imp-kat}
  rule <s> cut-point? [ STATE ] => pop STATE ; can? (^ while) ... </s> [structural]
```

### Define `abstract`

IMP will abstract by turning all the values in memory into fresh symbolic values.

```{.k .imp-kat}
  syntax Strategy ::= "#abstract" Set State | "#abstractKey" Id Set State
//-----------------------------------------------------------------------
  rule <s> abstract [ { KCELL | MEM } ] => #abstract keys(MEM) { KCELL | MEM } ... </s> [structural]
  rule <s> #abstract .Set STATE         => pop STATE                           ... </s> [structural]

  rule <s> #abstract (SetItem(X) XS) STATE   => #abstractKey X XS STATE                   ... </s> [structural]
  rule <s> #abstractKey X XS { KCELL | MEM } => #abstract XS { KCELL | MEM[X <- ?V:Int] } ... </s> [structural]
```

### Define `_subsumes_`

Because the memory is fully abstract every time subsumption is checked, it's enough to check that the `k` cell is identical for subsumption.

```{.k .imp-kat}
  rule <s> { KCELL | _ } subsumes? [ { KCELL  | _ } ] => #true  ... </s>                            [structural]
  rule <s> { KCELL | _ } subsumes? [ { KCELL' | _ } ] => #false ... </s> requires KCELL =/=K KCELL' [structural]
endmodule
```

### Example (Single Loop)

Execute this test file with `krun --search sbc.imp`.
Every solution will have it's own trace of generated rules.

```{.imp .sbc .k}
int n , s , x;

s = 0 ;
while (0 <= n) {
  n = n + -1 ;
  s = s + n ;
}

x = 0 ;
```

### Exmaple (Collatz)

### Example (Memory Walk)