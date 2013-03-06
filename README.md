#Quick Start

```julia
using Keyword
@def_generic Foo(x=>"Default x", y=>"Default y",z)
##:(Foo(x=>"Default x",y=>"Default y",z))

@def_method function Foo(x,y,z)
    println("in basic Foo")
    {:x=>x, :y=>y, :z=>z}
end

@def_method function Foo(x::Int,y,z)
    println("in special  Foo")
    {:x=>x, :y=>y, :z=>z}
end

@KC Foo()
##in basic Foo
##{x=>"Default x",y=>"Default y",z=>nothing}

@KC Foo(z=>2,x=>1)
##in special  Foo
##{x=>1,y=>"Default y",z=>2}
```

#About Keyword.jl
##Naming
The package is named in honor of the great language lisp.

##Design
The approach is modeled after how R's S4 methods work, lisp keywords, and my own thoughts.

##Why?
I started to take a look at julia and really liked what I saw.
But I really feel like it needs keyword function calls before I really start to use it.
So, I figured, why not add it myself. 

I mean, it has macros. So I can do anything I want right?
And I figured it would be a good way for me to really understand the language.

##Buyer Beware
Even though the package seems to be in a fairly usable state, I just want to point out the following.

1. This is still in an alpha\beta stage.
2. This is literally the first (and currently only) code I have written in julia.
3. This is also my first github repository.

##Efficient and User Friendly
From the start, I wanted this to be supper efficient.

Under normal cases, the only (run-time) overhead is comparing `object_id(fn)` of the function to a constant.

Even this overhead can be removed if you know for certain that the current binding of the function has not changed.
This is done with the `@KC!` macro. But this can have unexpected results if you don't know what you are doing.

Using the `_` symbol requires extra (run-time) overhead.

##TODOs
+ Add test cases.
+ Improve error messages.
+ Clean up the code.
+ Improve documentation.
+ Investigate tighter integration. (Have julia call @KC without needing to type it in.)

#Users Guide (of Sorts) (with Pictures)

##Basic Use
```julia
using Keyword
@def_generic Foo(x=>"Default x", y=>"Default y",z)
##:(Foo(x=>"Default x",y=>"Default y",z))

@def_method function Foo(x,y,z)
    println("in basic Foo")
    {:x=>x, :y=>y, :z=>z}
end

@def_method function Foo(x::Int,y,z)
    println("in special  Foo")
    {:x=>x, :y=>y, :z=>z}
end

@KC Foo()
##in basic Foo
##{x=>"Default x",y=>"Default y",z=>nothing}

@KC Foo(z=>2,x=>1)
##in special  Foo
##{x=>1,y=>"Default y",z=>2}
```

## Allowing Other Keys
The special symbol `_` absorbs other keys and spreads them into other functions (including those which do not allow other keys).
`_` should always be a the end of a function call.

At run time, `_` will be bound to a dots object which will contain the other values.
The dots object is not created by the user.

It is considered bad form to use the dots object directly.
Use the `dots_to_dict` function instead.

```julia
@def_generic Bar(xx=>"Default xx",zz,_)
##:(Bar(xx=>"Default xx",zz,_))

@def_method function Bar(xx,zz,qq=>"Default Basic qq",_)
    println("in basic Bar")
    {:xx=>xx, :zz=>zz, :qq=>qq, :_=>dots_to_dict(_), :Foo=>(@KC Foo(_))}
end


##Extra arguments can be type checked.
##But only formal arguments (those declared in @def_generic) can be dispatched on. 
@def_method function Bar(xx::Int,zz,
                         qq=>"Default Special q",
                         ww::Int=>1,
                         _)
    println("in special Bar")
    {:xx=>xx, :zz=>zz, :qq=>qq, :ww=>ww, :_=>dots_to_dict(_), 
     :Foo=>(@KC Foo(x=>"x:Bar->Foo",_))}
end

@KC Bar()
##in basic Bar
##in basic Foo
##{zz=>nothing,_=>Dict{Symbol,Any}(),qq=>"Default Basic qq",xx=>"Default xx",Foo=>{x=>"Default x",y=>"Default y",z=>nothing}}

@KC Bar(z=>2,xx=>1)
##in special Bar
##in basic Foo
##{zz=>nothing,_=>[z=>2],qq=>"Default Special q",ww=>1,xx=>1,Foo=>{x=>"x:Bar->Foo",y=>"Default y",z=>2}}

@KC Bar(y=>2)
##in basic Bar
##in basic Foo
##{zz=>nothing,_=>[y=>2],qq=>"Default Basic qq",xx=>"Default xx",Foo=>{x=>"Default x",y=>2,z=>nothing}}

@KC Bar(ww=>"A")
##in basic Bar
##in basic Foo
##{zz=>nothing,_=>[ww=>"A"],qq=>"Default Basic qq",xx=>"Default xx",Foo=>{x=>"Default x",y=>"Default y",z=>nothing}}

##Extra arguments can be type checked.
@KC Bar(xx=>1,ww=>"A")
##no method convert(Type{Int64},ASCIIString)

```

##Dynamic Usage
This shows how one can use the `dic_call` function.

```julia
dict_call(Bar, {:x=>2})
##in basic Bar
##in special  Foo
##{zz=>nothing,_=>[x=>2],qq=>"Default Basic qq",xx=>"Default xx",Foo=>{x=>2,y=>"Default y",z=>nothing}}
```

Here are some basic examples of how Keyword is able to "outsmart" the user.

```julia
let Bar=Foo, Foo=Bar
@KC Bar()
end
##WARNING: slow call. Bar changed.
##in basic Foo
##{x=>"Default x",y=>"Default y",z=>nothing}

bar_or_foo = Foo
@KC bar_or_foo()
##in basic Foo
##{x=>"Default x",y=>"Default y",z=>nothing}
```

##Required Arguments

Arguments with a trailing `!` (but no default), flag an error if
they are not supplied with a value at runtime.

```julia
@def_generic Qux(x!,y)
##:(Qux(x!,y))

@def_method function Qux(x,y)
   (x,y)
end

@KC Qux()
##You must supply a value for x
## in Qux at /home/chris/.julia/Keyword/src/Keyword.jl:325

@KC Qux(x=>2)
##(2,nothing)

```

You can override this behavior if you really want to.

```juila

##Note the space between x! and =>.
##This is required by julia to distinguish it from !=.
@def_generic Quux(x! =>3,y)
##:(Quux(x!=>3,y))

@def_method function Quux(x!,y)
   (x!,y)
end

@KC Quux()
##(3,nothing)

@KC Quux(x! =>2)
##(2,nothing)

```


##Delayed Evaluation


```julia
@def_generic Baz(x=>println("x evaluated at run time."))
:(Baz(x=>println("x evaluated at run time.")))

@def_method function Baz(x)
    println("in basic Baz")
    {:x=>x}
end

@KC Baz()
##x evaluated at run time.
##in basic Baz
##{x=>nothing}

@KC Baz(x=>1)
##in basic Baz
##{x=>1}
```

##Use With Other Modules
###Example 1
```julia

module A
using Keyword
keyword_init(A)

X() = println("in A's X")
Y() = println("in A's Y")
W() = println("in A's W")

@def_generic Foo(x=>X(), y=>Y(), _)
@def_method function Foo(x, y, w=>W(),_)
    (x,y,w)
end
f() = @KC Foo()

keyword_finalize()
end

A.f()
##in A's X
##in A's Y
##in A's W
##(nothing,nothing,nothing)

@KC A.Foo()
##in A's X
##in A's Y
##in A's W
##(nothing,nothing,nothing)
```

###Example 2

```julia
module C
using Keyword
keyword_init(C)

@def_generic Foo(x=>println("pull x"), y=>println("pull y"), _)
@def_method function Foo(x, y, w=>println("pull w"),_)
    (x,y,w)
end
f() = @KC Foo()

keyword_finalize()
end

C.f()
##pull x
##pull y
##pull w
##(nothing,nothing,nothing)

@KC C.Foo()
##pull x
##pull y
##pull w
##(nothing,nothing,nothing)
```

##A Look at the `@KC` and `@KC!` macros.
`@KC` stands for Keyed Call

```julia
macroexpand(:(@KC Foo()))
##:(if (0x1ba1dd69aac48c03$(Keyword).==$(Keyword).object_id(Foo))
##        Foo("Default x","Default y",Foo($(Keyword).Arg_Num(3)))
##    else 
##        $(Keyword).warn("slow call. Foo changed.")
##        $(Keyword).tuple_call(Foo)
##    end)

macroexpand(:(@KC! Foo()))
##:(Foo("Default x","Default y",Foo($(Keyword).Arg_Num(3))))

```


