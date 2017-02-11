#### Timestamp notices:  `Loba.ts`
Outputs a timestamped notice, useful for quick traces to see the code path and easier than, say, [Kernel#set_trace_func](http://ruby-doc.org/core-2.2.3/Kernel.html#method-i-set_trace_func).
Also does a simple elapsed time check since the previous timestamp notice to help with quick, minimalist profiling.

For example,

```
[TIMESTAMP] #=0002, diff=93.478016, at=1451444972.970602    (in=/home/usracct/src/myapp/app/models/target.rb:55:in `some_calculation')
```

To invoke,

```
Loba.ts    # no arguments
```

The resulting notice output format is

```
[TIMESTAMP] #=nnnn, diff=ss.ssssss, at=tttttttttt.tttttt    (in=/path/to/code/somecode.rb:LL:in 'some_method')
```

where
*   `nnn` ("#=") is a sequential numbering (1, 2, 3, ...) of timestamp notices,
*   `ss.ssssss` ("diff=") is number of seconds since the last timestamp notice was output (i.e., relative time),
*   `tttttttttt.tttttt` ("at=") is Time.now (as seconds) (i.e., absolute time),
*   `/path/to/code/somecode.rb` ("in=") is the source code file that invoked `Loba.ts`,
*   `LL` ("in=...:") is the line number of the source code file that invoked `Loba.ts`, and
*   `some_method`is the method in which `Loba.ts` was invoked.
