#include  <stdio.h>

//#define printf(TXT)

class Noop 
{
public:
	Noop() {}

	virtual void noop() const {};
private:
	Noop( Noop const& ) {}
};

class NoopState
{
public:
	NoopState( Noop const& noop )
		: m_noop( noop )
	{
	}

	Noop const& noop() const { return m_noop; }
	Noop const& m_noop;
};


class CrashTest
{
public:
	CrashTest( NoopState const& state ) 
		: m_state( state ) 
	{
	}

	void crash() const
	{
		printf("m_state.noop().noop();\n");
		m_state.noop().noop(); // no crash :-)
		printf("m_state.m_noop.noop();\n");
		m_state.m_noop.noop(); // crash :-(
		printf("OK!\n");
	}
private:
    NoopState const& m_state;
};

int main(int argc, char* argv[])
{
	Noop stack_noop;
	Noop const* noop(&stack_noop);

	if ( argc == 2 )
	{
		printf("Heap allocated Noop\n");
		noop = new Noop;
	}
	else
		printf("Stack allocated Noop\n");

	NoopState state( *noop );
	CrashTest test( state );

	test.crash();
}
