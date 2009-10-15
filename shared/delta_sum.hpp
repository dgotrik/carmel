#ifndef GRAEHL_SHARED__DELTA_SUM_HPP
#define GRAEHL_SHARED__DELTA_SUM_HPP

/*
  you want a sum (e.g. for avg.) of a function over time that doesn't change every sample (it's usually constant)
  report (change,time) or (value,time) points, and I can track that for you

  you can also set the value directly as long as it's for a time >= the latest (this just computes the delta for you)

 */

#include <stdexcept>
#include <graehl/shared/stream_util.hpp>

namespace graehl {

struct delta
{
    double d;
    double t;
    delta(double d,double t) :d(d),t(t) {  }
};


inline void throw_unknown_delta_sum(double t,double tmax) {
    throw std::runtime_error("delta_sum asked for forgotten sum at 0<t<tmax");
}

// can get any [0,t>tmax] sum or [t0>tmax,t>tmax] sum where tmax is the highest t of any delta
//TESTME:
//Essentially I forget the sum (s) at values of t<tmax.  I track the current instantaneous value x at time tmax, and so can give the sum over time from t=0..t' for any t'>=tmax (sum(t') below)
struct delta_sum
{
    double x,tmax;
    double s;
    delta_sum& addbase(double d) // same as add_delta(d,0)
    {
        s+=d*tmax;
        x+=d;
        return *this;
    }

    double extend(double t)
    {
        double moret=t-tmax;
        if (moret<0) throw_unknown_delta_sum(t,tmax);
        tmax=t;
        return s+=x*moret;
    }
    double sum(double t) const
    {
        if (t<=0) return 0;
        if (t>0 && t<tmax) throw_unknown_delta_sum(t,tmax);
        return s+(tmax-t)*x;
    }
    double sum(double t0,double tm) const
    {
        return sum(tm)-sum(t0);
    }
    double add_delta(delta const& d)
    {
        add_delta(d.d,d.t);
    }
    double add_delta(double d,double t)
    {
        double moret=t-tmax;
        if (moret>0) {
            tmax=t;
            s+=moret*x;
        } else if (moret<0) {
            s+=d*(-moret);
        }
        x+=d;
    }
    double add_val(double v,double t) // only works if t>=tmax, i.e. deltas/vals come in increasing order
    {
        add_delta(v-x,t);
    }
    delta_sum(double x0=0) { clear(x0); }
    void clear(double x0=0)
    {
        x=x0;
        s=tmax=0;
    }

    bool empty() const
    {
        return tmax==0;
    }
    typedef delta_sum self_type;
    TO_OSTREAM_PRINT
    template<class O>
    void print(O &o) const
    {
        o<<"x("<<tmax<<")="<<x<<" sum="<<s;
        if (tmax>0)
            o<<" avg="<<s/tmax;
    }
};

// tmax fixed in advance!  essentially no advantage over more flexible delta_sum except barely simpler computation
//TESTME:
struct bounded_delta_sum
{
    double x;
    double tmax;
    double s;
    double extend(double t)
    {
        assert(t==tmax);
        return s;
    }
    bool empty() const
    {
        return x==0;
    }
    double sum() const
    {
        return s;
    }
    double sum(double t) const
    {
        if (t<=0) return 0;
        double extrat=t-tmax;
        if (extrat<0) throw_unknown_delta_sum(t,tmax);
        return s+x*extrat;
    }

    double add_delta(double d,double t)
    {
        double tleft=tmax-t;
        if (tleft>=0) {
            s+=tleft*d;
            x+=d;
        }
    }
    double add_delta(delta const& d)
    {
        add_delta(d.d,d.t);
    }
    double add_val(double v,double t)
    {
        add_delta(v-x,t);
    }
    bounded_delta_sum(double x0,double tmax) : x(x0),tmax(tmax),s(0) {  }
    typedef bounded_delta_sum self_type;
    TO_OSTREAM_PRINT
    template<class O>
    void print(O &o) const
    {
        o<<"x(t<"<<tmax<<")="<<x<<" sum="<<s;
        if (tmax>0)
            o<<" avg="<<s/tmax;
    }
};


}


#endif