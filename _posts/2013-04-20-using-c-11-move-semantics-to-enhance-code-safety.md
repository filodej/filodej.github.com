---
layout: article
uuid: 0f82ee66-7808-418a-afc3-9318d0690a57
title: Using C++11 move semantics to enhance code safety
name: using-c-11-move-semantics-to-enhance-code-safety
created_at: 2013-04-20
updated_at: 2013-04-20
categories: unfinished
---

Overview
========

Let's say we have a fairly big codebase. The code is relatively portable
and is regularly built on several platform's native compilers. The platforms 
and compilers are:

 * Linux (GCC 4.3)
 * Windows (VS2010)
 * AIX
 * HPUX
 * Solaris

There is an effort to move to GCC on all unixes but it does not seem to be 
the case in a forseeable future.

There is no problem to use lets say Clang 3.2 or GCC 4.8 just for better error 
diagnostics as far as the source code still works on the old compilers as well.

The question is:

Can we utilize the new C++ standard in order to make the source code better
and have it buildable on the old compilers?

Conversion helper
=================

We have the following conversion helper, which generically encapsulates all kinds 
of unicode text conversions

  * UTF-8 (char)
  * UTF-16 (wchar_t)
  * UTF-16 (char16_t)
  * UTF-32 (char32_t)
  * ...

The actual conversion is realized in the `do_conversion()` helper and is not really 
important in this context.

What is important is that we have some generic string definition which looks something 
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
string format have code like this:

	std::cout << "This is ok: " << convert<char>( s1 ).c_str() << std::endl;

The helper class called `convert` ougth to be clever enough to incur a minimal overhead
in case there is no need for a conversion. 

Such helper class can look something like this:

	template <typename CharT>
	class convert
		: public boost::noncopyable
	{
	public:
		typedef CharT char_type;
		typedef size_t size_type;
		typedef std::basic_string<char_type> string_type;
		
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
		
	private:
		string_type m_buffer;
		char_type const* m_text;
		size_type m_length;
	};


	std::wstring const hi( L"Hello");
	std::cout << "This is ok: " << convert<char>( s1 ).c_str() << std::endl;

	std::cout << "This is ok: " << convert<char>( std::wstring( L"Hello") ).c_str() << std::endl;
