---
name: using-c-11-move-semantics-to-enhance-code-safety
layout: post
uuid: 0f82ee66-7808-418a-afc3-9318d0690a57
title: Using C++11 move semantics to enhance code safety
time: 2013-04-20 23:05
categories: programming cpp
---
Overview
========

Let's say we have a fairly large codebase. The code is relatively portable
and besides *Windows* (MSVC 2010) and *GNU/Linux* (GCC 4.3) it is regularly 
built with several target platform's native compilers (*AIX*, *HP-UX*, *Solaris*). 
There is an effort to move to *GCC* on all Unix systems but it does not seem 
to be the case in a forseeable future.

As we have a decent [Continue integration](http://en.wikipedia.org/wiki/Continuous_integration) 
environment like [Jenkins](http://jenkins-ci.org) or [Buildbot](http://buildbot.net/) 
there is no problem to use lets say *Clang 3.2* or *GCC 4.8* just for early error 
diagnostics as far as the source code remains to work on the old compilers as well.

The question we want to address is:

>  Can we utilize the new [C++11 standard](http://en.wikipedia.org/wiki/C%2B%2B11) 
>  in order to make the source code better but still buildable with old compilers?

Conversion helper
=================

We have the following conversion helper, which generically encapsulates all kinds 
of unicode text conversions ([UTF-8](http://en.wikipedia.org/wiki/UTF-8) `char`, 
[UTF-16](http://en.wikipedia.org/wiki/UTF-16) `wchar_t`, 
UTF-16 `char16_t`, [UTF-32](http://en.wikipedia.org/wiki/UTF-32) `char32_t`, ...).

The actual conversion is realized in the `do_conversion()` helper and is not really 
important in this context.

What is important is that we have some generic `string` definition which looks something 
like following:

	#if ( XSTRING_FORMAT == 8 )
	typedef char XChar;
	#elif ( XSTRING_FORMAT == 16 )
	typedef char16_t XChar;
	#elif ( XSTRING_FORMAT == -16 )
	typedef wchar_t XChar;
	#elif ( XSTRING_FORMAT == 32 )
	typedef char32_t XChar;
	#endif

	typedef std::basic_string<XChar> XString;

... and then in many places, when we are interfacing with an API accepting a particular 
`string` format have code like this:

	std::cout << "This is ok: " << convert<char>( s1 ).c_str() << std::endl;

The helper class called `convert` ought to be clever enough to incur a minimal overhead
in case there is no need for a conversion. 

Such helper class can look something like this:

	template <typename CharT>
	class convert
	{
	public:
		typedef CharT char_type;
		typedef size_t size_type;
		typedef std::basic_string<char_type> string_type;
		typedef converter this_type;
		
		// no conversion performed => no overhead 
		convert( string_type const& text )
			: m_text( text.c_str() )
			, m_length( text.size() )
		{
		}
		
		template <typename T>
		convert( std::basic_string<T> const& text )
			: m_buffer( do_conversion<CharT>( text.c_str(), text.size() ) )
			, m_text( m_buffer.c_str() )
			, m_length( m_buffer.size() )
		{
		}
		
		CharT const* c_str() const
		{ 
			return m_text; 
		}
		
		size_type length() const { return m_length; }

	private:  // make this class noncopyable
		convert( this_type const& );
		this_type const& operator=( this_type const& );
		
	private:
		string_type const m_buffer;
		char_type const* const m_text;
		size_type const m_length;
	};

This implementation works relatively well as far as no one violates a single rule:

>  Lifetime of the `convert<>` object may never exceed lifetime of the `string` it is converting

The problem is demonstrated in the following code:

	// case #1: converting an L-value in a single expression is OK
	std::cout << "This is ok: " << convert<char>( s1 ).c_str() << std::endl;

	// case #2: converting an R-value (temporary) in a single expression is OK
	std::cout << "This is ok: " << convert<char>( s1 + s2 ).c_str() << std::endl;

	// case #3: converting an L-value with a named converter<> is OK
	convert<char> const t1( s1 );
	std::cout << "This is ok: " << t1.c_str() << std::endl;

	// case #4: converting an R-value (temporary) with a named converter<> is BAD
	convert<char> const t12( s1 + s2 );
	std::cout << "Oooops!: " << t12.c_str() << std::endl;

The question is: 

>  Are we able to distinguish between the four cases demonstrated above and make sure
>  the **#4** never appears in our codebase?

*C++11* at our service
======================

Fixed version
-------------

When we start compiling the source with *C++11* language version (`-std=c++11` compiler setting)
many new opportunities open up for us. 

If we add the following two constructor overloads we have fully functional solution
even for case **#4**.

	convert( string_type&& text )
		: m_buffer( std::move( text ) ) // here we grab'n'reuse the source buffer
		, m_text( m_buffer.c_str() )
		, m_length( text.size() )
	{
	}

 	template <class T>
	convert( std::basic_string<T>&& text )
		: convert( text ) // we are intentionally not moving (we convert anyway)
	{
	}

The two new constructors are called anytime a temporary `string` is passed to the `convert<>`.
If there is no conversion to be done, we just grab the guts of the temporary `string` 
and so prolong its lifetime as long as we need it.
 
The problem is that now we are outside the scope of *C++03* and so this code does not work 
on the old compilers. So this approach helps us on new compilers but does not compile 
on the old ones - not quite what we are looking for.

Input R/L valuedness
--------------------

What if we make those two constructors *private* instead and so make sure there is 
no one using the conversion this way? 

Then we have only "nice" clients and we are safe on all other platforms thanks to 
the fact that we just make a *sanity check build* once a day or so.

	#ifdef HAS_MOVE_SEMANTICS
	
	#ifdef CHECK_BACKWARD_COMPATIBILITY
	private:
	#endif // CHECK_BACKWARD_COMPATIBILITY

		convert( string_type&& text )
			: m_buffer( std::move( text ) ) // here we grab'n'reuse the source buffer
			, m_text( m_buffer.c_str() )
			, m_length( text.size() )
		{
			// case #2 or #4
		}

 		template <class T>
		convert( std::basic_string<T>&& text )
			: convert( text ) // we are intentionally not moving (we convert anyway)
		{
			// case #2 or #4
		}
	#endif // HAS_MOVE_SEMANTICS
    
The problem is that this approach disables all clients trying to convert *R-value* string;
even ones doing that in a single expression (one-liner conversions).

The case **#2** (which is perfectly OK) now fails to compile:

	// case 2: converting an R-value (temporary) in a single expression is OK
	std::cout << "This is ok: " << convert<char>( s1 + s2 ).c_str() << std::endl;

What we need is a way to distinguish between case **#2** and case **#4**.
It is not the *R-valuedness* of input what is wrong, it is *the combination*
of input `string` *R-valuedness* and *L-valuedness* of the `convert<>` object.

Converter R/L valuedness
------------------------

Now we have to distinguish cases when the `convert<>` class is instantiated
as a one-liner (*R-value*) from cases when it is created as a named variable (*L-value*).

What we are basically looking for is a similar overload for the `convert<>` constructor 
like we have for the input `string` value. 

If *C++* had explicit `this` parameter instead of implicit (like *Python* has with its first 
method argument, conventionally called `self`), then we could try something like this:

	convert( this_type&& self, string_type const& text ) { /* case #1 - OK * / }

	convert( this_type&& self, string_type&& text )  { /* case #2 - OK * / }

	convert( this_type const& self, string_type const& text )  { /* case #2 - OK * / }

	convert( this_type const& self, string_type&& text )
	{
		// case #4 - ERR
		static_assert( 0, "Temporary values must be converted as a one-liner" );
	}

Actually - as there are well known [cv-qualifiers](http://en.wikipedia.org/wiki/Const-correctness) 
- newly there are also *ref-qualifiers* (see paper
[Extending move semantics to *this](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2439.htm) ).

	convert( string_type const& text ) && { /* case #1 - OK * / }

	convert( string_type&& text ) && { /* case #2 - OK * / }

	convert( string_type const& text ) & { /* case #3 - OK * / }

	convert( string_type&& text ) &
	{
		// case #4 - ERR
		static_assert( 0, "Temporary values must be converted as a one-liner" );
	}

The problem is that *ref-qualifiers* cannot be applied to constructors 
(neither to desctructors, static methods), just to ordinary methods. 

So what about the `convert<>::c_str()` method?

The following code works perfectly OK (I have tested it on *Clang 3.0*, 
it should work since *Clang 2.9* according to the 
[Clang C++11 status page](http://clang.llvm.org/cxx_status.html) and since
*GCC 4.8.1* according to the [GCC C++11 status page](http://gcc.gnu.org/projects/cxx0x.html) ).

	CharT const* c_str() const&
	{ 
		// case #3 or #4
		return m_text; 
	}

	CharT const* c_str() &&
	{ 
		// case #1 or #2
		return m_text; 
	}

The problem here is that we lost track of the input *R/L-valuedness* and so cannot
distinguish between case **#3** (OK) and **#4** (Error).

So what we need is to transfer the input valuedness from the constructor to the 
`c_str()` method. We could definitely store it in a variable and assert in runtime, 
but it is not what we really want. 

We want to find a way to fail early - in compile time.

Unfortunately I did not find a full solution for this problem. 
As the *R/L valuedness* of a `convert<>` instance  is not known in 
scope of its *constructor* we are not able to combine the two necessary 
bits of information (*R/L-valuedness* of both *input value* and *convert<>*) 
in one place.

Thankfully there is a not so bad workaroung for this problem though.

`convert<>` vs. `coverter<>`
----------------------------

It requires a change in client code, but fortunately it is quite mechanical change
which can be easily automated.

First we rename the `convert<>` template class to `converter<>`.

Then we create a perfectly forwarding template function called convert<> as follows: 

	template <typename CharT, typename T>
	inline converter<CharT> convert( T&& text )
	{
		return converter<CharT>( std::forward<T>( text ) ); 
	} 

To the original version of the `convert<>` (now its name is `converter<>`) we add the 
following code:

	#ifdef HAS_MOVE_SEMANTICS
	#ifdef CHECK_BACKWARD_COMPATIBILITY
	private:
		// Following constructors are not allowed before we have C++11 support 
		// on all target platforms
		// (r-value string conversion must be performed within the same expression)
		template <typename CT, typename T>
		friend converter<CT> convert( T&& text );
	#endif
 
		converter( this_type&& rhs )
			: m_buffer( std::move( rhs.m_buffer ) )
			, m_text( std::move( rhs.m_text ) )
			, m_length( std::move( rhs.m_length ) )
		{
		}

		converter( string_type&& text )
			: m_buffer( std::move( text ) ) // here we grab'n'reuse the source buffer
			, m_text( m_buffer.c_str() )
			, m_length( text.size() )
		{
		}

 		template <class T>
		converter( std::basic_string<T>&& text )
			: converter( text ) // we are intentionally not moving (we convert anyway)
		{
		}

	#endif // HAS_MOVE_SEMANTICS

To be able to return the `converter<>` out of the factory `convert<>` function
it was necessary to make the *non-copyable* `converter<>` *movable* (add *move 
constructor*).
 
Now we are back in the version with *private constructors* accepting *R-value* input
but now we have a back door helper function called `convert<>` which we can use for 
one-line conversions.

Now it is necessary to replace all the named (*L-value*) `convert<>` instances with 
`converter<>` in client code while keeping all one-line conversions intact.

	// case #1: converting an lvalue in a single expression is OK
	std::cout << "This is ok: " << convert<char>( s1 ).c_str() << std::endl;

	// case #2: converting an rvalue (temporary) in a single expression is OK
	std::cout << "This is ok: " << convert<char>( s1 + s2 ).c_str() << std::endl;

	// case #3: converting an lvalue with a named converter<> is OK
	converter<char> const t1( s1 );
	std::cout << "This is ok: " << t1.c_str() << std::endl;

	// case #4: converting an rvalue (temporary) with a named converter<> is BAD
	converter<char> const t12( s1 + s2 );
	std::cout << "Oooops!: " << t12.c_str() << std::endl;

Now if we compile the source code with the `CHECK_BACKWARD_COMPATIBILITY` 
macro defined we get the following compiler error for the case **#4**:

*Clang 3.0*:
	movement.cpp:38:24: error: calling a private constructor of class 'converter<char>'
	        converter<char> const t12( s1 + s2 );
	                              ^
*GCC 4.7*:
	././convert_impl.hpp:65:2: error: ‘converter<CharT>::converter(std::basic_string<T>&&) 
		[with T = wchar_t; CharT = char]’ is private
	movement.cpp:38:37: error: within this context

The last step is to make the `convert<>` and `converter<>` work the same way 
on the old compilers.

For that we would love to use *template alias*:

	template <typename CharT>
	using convert = converter<CharT>;

... but unfortunately it was not available before the *C++11*.
 
What remains as a workaround is either the following ugly preprocessor hack:

	#define convert converter

... or we can use inheritance:

	template <typename CharT>
	class convert 
		: public converter<CharT>
	{
		typedef converter<CharT> base_type;
	public:
		using typename base_type::char_type;
		using typename base_type::size_type;
		using typename base_type::string_type;

		convert( string_type const& text )
			: base_type( text )
		{
		}

		template <typename T>
		convert( std::basic_string<T> const& text )
			: base_type( text )
		{
		}
	};

Unfortunately it is not trivial as we need to bridge *constructors* 
and *local typedefs* as can be seen above.

Conclusion
==========

The *C++11 standard* greatly extends what the language is able to express.
Especially the move semantics opens many opportunities for various kinds 
of optimizations.

As we seen this new expresivness is valuable not only for performance but 
also for correctness of the source code.

And even though you cannot use the *new standard* directly in production 
(e.g. due to some historical reasons) you can still utilize the new language 
features as a kind of [static code analysis](http://en.wikipedia.org/wiki/Static_program_analysis).  

Source code
-----------

The source code for this experiment is available [here](http://github.com/filodej/move-semantics).

I was able to build it succesfully with GCC 4.7.2 and Clang 3.0.