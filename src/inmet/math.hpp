#pragma once

namespace aux {

struct PolyFit {
    idx nfit;
    inarray coeffs, ncoeffs;
};

using inpoly = PolyFit const&;
using outpoly = PolyFit&;

//typedef cptr<PolyFit const> inpoly;

void eval_poly(inpoly poly, inarray x, outarray y);

}