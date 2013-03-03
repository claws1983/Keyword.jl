
##Basic usage

using Keyword
@def_generic Foo(x=>"Default x", y=>"Default y",z)

@def_method function Foo(x,y,z)
    println("in basic Foo")
    {:x=>x, :y=>y, :z=>z}
end

@def_method function Foo(x::Int,y,z)
println("in special  Foo")
{:x=>x, :y=>y, :z=>z}
end

@KC Foo()
@KC Foo(z=>2,x=>1)

## allow_other_keys

## the special symbol "_" absorbs other keys and spreads them into other functions (including those which do not allow other keys)"
## _ should always be a the end of a function call.

## at run them, the _ will be bound to "dots" object.
## the dots object is not created by the user.

## it is considered bad form to use the dots object directly.
## use the dots_to_dict function instead.
@def_generic Bar(xx=>"Default xx",zz,_)

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
    {:xx=>xx, :zz=>zz, :qq=>qq, :ww=>ww, :_=>dots_to_dict(_), :Foo=>(@KC Foo(_))}
end

@KC Bar()
@KC Bar(z=>2,xx=>1)
@KC Bar(y=>2)
@KC Bar(ww=>"A")

##error
##@KC Bar(xx=>1,ww=>"A")


##Dynamic
let Bar=Foo, Foo=Bar
@KC Bar()
end

bar_or_foo = Foo
@KC bar_or_foo()


dict_call(Bar, {:x=>2})

##delayed evaluation
@def_generic Baz(x=>println("x evaluated at run time."))

@def_method function Baz(x)
    println("in basic Baz")
    {:x=>x}
end

@KC Baz()
@KC Baz(x=>1)



##use with other Modules

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

##Error
##@KC A.Foo()
##TODO::Look into automatically qualifying defaults.
##For now, defaults should be explictly qualified as shown below.
##This is due to the fact taht defaults are evaluated at run time and not macroexpand time.



module B
using Keyword
keyword_init(B)

X() = println("in B's X")
Y() = println("in B's Y")
W() = println("in B's W")

@def_generic Foo(x=>B.X(), y=>B.Y(), _)
@def_method function Foo(x, y, w=>B.W(),_)
    (x,y,w)
end
f() = @KC Foo()

keyword_finalize()
end

B.f()
@KC B.Foo()


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
@KC C.Foo()
