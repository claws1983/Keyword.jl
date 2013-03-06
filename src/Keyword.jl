## Copyright 2013 Chris Laws

## This file is part of Keyword.jl.

## Keyword.jl is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.

## Keyword.jl is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.

## You should have received a copy of the GNU General Public License
## along with Keyword.jl.  If not, see <http://www.gnu.org/licenses/>.


module Keyword
export @def_generic, @def_method, @KC, @KC!, dict_call, dots_to_dict, missing, keyword_init, keyword_finalize

##These are only exported so they won't be deleted.
##They are not indented for use by the user.
export @dots_get, @get




quot(ex) = expr(:quote, ex)
set_expr(lhs, rhs) = expr(symbol("="), lhs, rhs)
arrow_exp(lhs, rhs) = expr(symbol("=>"), lhs, rhs)

ierror(x)=error("ERROR: " * x)
add! = add
macro get(dict,key,default)
    edict = esc(dict)
    ekey = esc(key)
    edefault = esc(default)
    quote
        if has($(edict), $(ekey))
            $(edict)[$(ekey)]
        else
            $edefault
        end
    end
end

const missing = nothing
esc(x) = x == :missing ? x : Base.esc(x)
const _dots_sym = :_
global eval_for_object_id = Main.eval
keyword_init(m::Module) = global eval_for_object_id = m.eval
keyword_finalize() = global eval_for_object_id = Main.eval




type Dots
    map::Dict{Symbol, Any}
end

dots() = Dots((Symbol=>Any)[])
function dots(x...)
    d=dots()
    if (length(x) %2) != 0
        ierror("dots requires an even number of arguments")
    end
    for i in 1:(length(x)/2)
        d.map[x[2*i-1]] = x[2*i]
    end
    return d
end
    
dots_has(d::Dots, s::Symbol) = has(d.map, s)
dots_get(d::Dots, s::Symbol) = (d.map)[s]
function dots_delete!(d::Dots, s::Symbol)
    if dots_has(d, s)
        delete!(d.map, s)
    end
    return d
end

function dots_copy(d::Dots)
    dots_new = dots()
    m_old = d.map
    m_new=dots_new.map
    
    for (k,v) in m_old
        m_new[k] = v
    end
    return dots_new
end
dots_to_dict(d::Dots) = dots_copy(d).map

macro dots_get(dict,key,default,delete)
    edict = esc(dict)
    ekey = esc(key)
    edefault = esc(default)
    quote
        if dots_has($edict, $ekey)
            let x = dots_get($edict,$ekey)
                if $delete
                    dots_delete!($edict, $ekey)
                end
                x
            end
        else
            $edefault
        end
    end
end


type Arg_Num
    num::Int
end
const ConstLang = Union(Number, ASCIIString)


eval(quote
    type Gen_Info
        id::($(typeof(object_id(+))))
        sym::Symbol
        defaults::Array
        allow_other_keys::Bool
    end
end)

registered_generics_obj_expr = quote
    ($(typeof(object_id(+)))=>Gen_Info)[]
end

const registered_generics_obj = eval(registered_generics_obj_expr)

function tuple_call(fn::Function, args...)
    d = (Symbol=>Any)[]
    for (k,v) in args
        d[k] = v
    end
    dict_call(fn, d)
end

delete_registered_generic(fn::Function) = delete!(registered_generics_obj, object_id(fn))


##This the main entry to the dynamic calling facility.
##The function ensures that dict contains and only contains formal arguments for fn.
##All other arguments are put in the the dots object if applicable.
##If the function allows_other_keys, we ensure that the dict contains a valid dots object keyed by _dots_sym.
function dict_call(fn::Function, dict::Dict{Symbol,Any})
    dict = copy(dict)
    fn_id = object_id(fn)
    info = registered_generics_obj[fn_id]
    defaults = info.defaults
    defaults_m = args_to_map(info.defaults)
    allow_other_keys = info.allow_other_keys
    
    dict[_dots_sym] = get(dict, _dots_sym, dots())
    dict[_dots_sym] = dots_copy(dict[_dots_sym])
    dd = dict[_dots_sym]
    
    extra_args = filter((k,v)-> !has(defaults_m,k),
                        dict)

    for (k,v) in defaults
        if dots_has(dd, k) && !has(dict, k)
            dict[k] = dots_get(dd,k)
            dots_delete!(dd, k)
        end
    end

    if allow_other_keys
        dict[_dots_sym] = fix_up(dd, extra_args...)
    else
        delete!(extra_args, _dots_sym)
        delete!(dict, _dots_sym)
        if length(extra_args) != 0
             error("unsupported arg to $fn in $dict")
        end
    end
    args = {}
    for i in 1:length(defaults)
        (k,v) = defaults[i]
        push!(args, 
              @get(dict,
                   k,
                   isa(v,ConstLang) ? v : fn(Arg_Num(i))))
              
            
    end

    fn(args...)
end

function dict_call(fn::Function, dict::Dict)
    dnew = (Symbol=>Any)[]
    for (k,v) in dict
        if !isa(k, Symbol)
            ierror("$k is not a symbol")
        end
        dnew[k] = v
    end
    dict_call(fn, dnew)
end

## function dict_call(fn::Function, dict::Dict{Symbol,Any})
##     fn_id = object_id(fn)
##     if has(dict, _dots_sym)
##         error("cannot dict_call a function if the dict contains $_dots_sym\n")
##     end
##     dict_call(fn_id, dict)
##end

##dict_call(fn::Function, dict::Dict) = dict_call(object_id(fn), dict)
dict_call(fn::Function) = dict_call(fn, (Symbol=>Any)[])  




function get_val_expr(key, explicit, defaults, using_dots)
    if has(explicit, key)
        esc(explicit[key])
    elseif !using_dots
        ##TODO: add meaningful error message
        (defaults[key])
    elseif has(defaults, key)
        :(@dots_get($(_dots_sym),
                    $(quot(key)),
                    $((defaults[key])),
                    true))
    end
end




##TODO: this will allow for overriding of values already in dots
## Do we want this?
function fix_up(dots::Dots, to_add...)    
    dots_new = dots_copy(dots)
    for (k,v) in to_add 
        dots_new.map[k] = v
    end
    return dots_new
end
fix_up(dots::Dots) = dots_copy(dots)


function args_to_map(args::Vector)
    a = Dict()
    for i in args
        a[i[1]] = i[2]
    end
    return a
end

function args_to_vector(args)
    out = {}
    
    for i in args
        if isa(i, Symbol) || i.head == symbol("::")
            arg_i = i
            default_i = :(missing)
        else
            mapping_term_i = i
            arg_i = mapping_term_i.args[1]
            default_i = mapping_term_i.args[2]
        end
        push!(out, {arg_i, default_i})
    end
    return out
end

args_to_map(args::Expr) = args_to_map(args_to_vector(args))



macro def_generic(x)    
    name_uq = x.args[1]
    name = quot(x.args[1])

    ##naked symbols with a trailing '!' are treated special
    ##They, by default, flag an error.
    
    args= {
           if (isa(y, Symbol) && string(y)[end] == '!')
               k = symbol(string(y)[1:(end-1)])
               arrow_exp(k,
                         :(($Keyword).error($"You must supply a value for $k")))
           else
               y
           end
           for y in x.args[2:]}
    args = args_to_vector(args)
    args_m = args_to_map(args)
    args_ = {expr(:cell1d, quot(y[1]), quot(y[2])) for y in args}
    allow_other_keys = args[end][1] == _dots_sym
        
    for (y1,y2) in args
        if !isa(y1, Symbol)
            ierror("generic declarations cannot specify type")
        end
    end
        
    if length(args) > 1
        for i in 1:(length(args)-1)
            if args[i][1] == _dots_sym
                ierror("found \"$_dots_sym\" in non ultimate position")
            end
        end
        
        
        if length(unique({k for (k,v) in args})) != length(args)
            ierror("found non unique key")
        end
    end
   arg_num_sym = esc(gensym("num"))    
  
                   
  closure={}
  for i in 1:length(args)
      push!(closure,
            quote
                if  num == $i
                    return $(esc(args[i][2]))
                end
            end)
      
  end
  push!(closure, :(num = ($arg_num_sym).num))
  reverse!(closure)


    quote
        function $(esc(name_uq)) ()
            $(quot(x))
        end

        if has(registered_generics_obj,object_id($(esc(name_uq))))
            warn("Overriding current generic.\n"*
                 "This can cause unexpected results.\n"*
                 "Consider recompiling.")
        end

        function $(esc(name_uq)) ($(arg_num_sym)::Arg_Num)
            $(expr(:block, closure...))
            error("can't go that high")
        end
 
        registered_generics_obj[object_id($(esc(name_uq)))] =
        Gen_Info(object_id($(esc(name_uq))),
                 $(esc(name)),
                 $(expr(:cell1d, args_...)),
                 $allow_other_keys)

        finalizer($(esc(name_uq)), delete_registered_generic)
        $(quot(x))
    end
end



##TODO: Perform an escape analysis.
##We don't want the user to return the Dots object.
macro def_method(x)
    args = x.args[1].args[2:]
    body = x.args[2]
    args_v = args_to_vector(args)
    name = x.args[1].args[1]
    info = registered_generics_obj[eval_for_object_id(:(object_id($name)))]
    id = info.id
    defaults = info.defaults
    allow_other_keys = info.allow_other_keys
    if allow_other_keys
        defaults = defaults[1:(end-1)]
    end

    error_info = "\ndefaults: $[d[1] for d in defaults]\n" *
    "supplied: $args" 

    if (allow_other_keys && args_v[end][1] != :_)
        ierror("this method requires _ at the end")
    end
    

    for i in 1:length(defaults)
        (k,v) = args_v[i]
        (kd,vd) = defaults[i]
        if (isa(k, Symbol) &&
            k != kd ) ||
            (isa(k, Expr) &&
             k.head == symbol("::") &&
             k.args[1] != kd )
            ierror("the arguments supplied do not match the FORMAL arguments" *
                  error_info*
                  "\n$args_v")
        end
        
        if v != :missing 
            ierror("tried to overried a FORMAL arguments default" *
                   error_info *
                   "\n$args_v")
        end
    end


    if (!allow_other_keys && (length(defaults) != length(args)))
        ierror("lengths of declared FORMALS and supplied args do not match\n" *
              error_info)   
    end

    extra_args = args_v[(length(defaults)+1):(length(args_v)-1)]
    formal_args = args_v[1:length(defaults)]
    if allow_other_keys
        push!(formal_args, {expr(symbol("::"),
                                 _dots_sym,
                                 expr(symbol("."), :Keyword, quot(:Dots))),
                            missing})
    end
    
    call_form = expr(:call, name, [x[1] for x in formal_args]...)

    drop_type=(x)->
        if !isa(x,Symbol)
            x.args[1]
        else
            x
        end
       
        setting_form = [
                        let
                        ek = esc(k)
                        ek_ = esc(drop_type(k))
                        qk_ = quot(drop_type(k))
                        
                        :($k = @dots_get($_dots_sym,
                                         $qk_,
                                         $v,
                                         true))
                        end
                        
                        for (k,v) in extra_args]
                             
                            
                            
   
        quote
            if $id != object_id($(esc(name)))
                error("value of function changed. cannot def_method")
            end
            
            $(expr(:function, esc(call_form),
                   esc(expr(:let, 
                            body,
                            setting_form...))))
        end

end


close_over(fn_name, arg_num, default::ConstLang) = default
function close_over(fn_name, arg_num, default)
    expr(:call, fn_name, :(Arg_Num($arg_num)))
end



function expand_key_call(x)
    args = x.args[2:]
    
    supplied_args = args_to_map(args_to_vector(args))
    name = x.args[1]
    ename = esc(name)
    info = registered_generics_obj[eval_for_object_id(:(object_id($name)))]
    defaults = info.defaults

    for i in 1:length(defaults)
        defaults[i][2] = close_over(ename,i, defaults[i][2])
    end
    
    defaults_m = args_to_map(defaults)
    allow_other_keys = info.allow_other_keys
    if allow_other_keys
        defaults = defaults[1:(end-1)]
    end

    error_info = "\ndefaults: $[d[1] for d in defaults]\n" *
    "supplied: $args"
    

    using_dots = has(supplied_args, _dots_sym)
  
    fixed_formals = {get_val_expr(k,
                                  supplied_args,
                                  defaults_m,
                                  using_dots) for (k,v) in defaults}

    extra_args = Dict()
    extra_args_sym = Set()
    as_sym = (x) -> if isa(x, Symbol)
        x
    else
        x.args[1]
    end
    
    for (k,v) in supplied_args
        if !has(defaults_m, k)
            if has(extra_args_sym, as_sym(k))
                ierror("found duplicate for $k in extra args")
            end
            add!(extra_args_sym, (as_sym, k))
            extra_args[k] = v
        end
    end


    if !allow_other_keys &&
        length(extra_args) != 0 &&
        !(length(extra_args) == 1 && has(extra_args, :_))
        ierror("this method does not allow other keys." *
              "and you supplied the folllowing as extra keyed args.\n"*
              "$extra_args \n")
    end
    
    call = expr(:call, ename, fixed_formals...)

    if allow_other_keys
    
        if !using_dots
            dots_exp = :(dots())
        else
            dots_exp = _dots_sym
        end
        to_add = {expr(:tuple, quot(k), v) for (k,v) in extra_args}
                          
        push!(call.args, expr(:call, :fix_up, dots_exp, to_add...))                
    end

    if using_dots
        call = quote
            let $(_dots_sym) = dots_copy($(esc(_dots_sym)))
                $call
            end
        end
    end
    

    return call
  
end




macro KC!(x)
    expand_key_call(x)
end

macro KC(x)

    name = x.args[1]
    ename = esc(name)
    info = registered_generics_obj[eval_for_object_id(:(object_id($name)))]
    id = info.id
    defaults_m = info.defaults
    args = x.args[2:]
    
    supplied_args = args_to_map(args_to_vector(args))   
    using_dots = has(supplied_args, _dots_sym)


    no = {expr(:tuple, quot(k),
               if k == _dots_sym
                   esc(_dots_sym)
               else
                   esc(v)
               end)
          for (k,v) in args_to_vector(x.args[2:])}
    no = expr(:call, :tuple_call, ename,
              no...)
    if using_dots
        no = :(let $(_dots_sym) = dots_copy($(esc(_dots_sym)))
            $no
        end)
        
    end
    expr(:if,
         expr(:comparison, id, symbol("=="), expr(:call, :object_id, ename)),
         expr(:block, expand_key_call(x)),
         expr(:block,
              expr(:call, :warn, "slow call. $name changed."),
              no))
end
end #module

