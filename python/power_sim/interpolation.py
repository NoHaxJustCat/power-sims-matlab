"""Minimal PCHIP (monotone cubic Hermite) interpolation.

The MATLAB source uses interp1(..., 'pchip') to get end-of-life Vmp/Imp and
temperature coefficients from fluence lookup tables. scipy isn't installed
in this environment, so this module reimplements the standard
Fritsch-Carlson monotone-cubic algorithm (the same method MATLAB's pchip
uses) directly on top of numpy to avoid adding a dependency.
"""
import numpy as np


def _end_derivative(h0, h1, d0, d1):
    """Non-centered, shape-preserving end-point slope (matches MATLAB pchip)."""
    d = ((2 * h0 + h1) * d0 - h0 * d1) / (h0 + h1)
    if np.sign(d) != np.sign(d0):
        d = 0.0
    elif (np.sign(d0) != np.sign(d1)) and (abs(d) > abs(3 * d0)):
        d = 3 * d0
    return d


def pchip_derivatives(x, y):
    n = len(x)
    h = np.diff(x)
    delta = np.diff(y) / h
    d = np.zeros(n)

    for i in range(1, n - 1):
        if delta[i - 1] == 0 or delta[i] == 0 or np.sign(delta[i - 1]) != np.sign(delta[i]):
            d[i] = 0.0
        else:
            w1 = 2 * h[i] + h[i - 1]
            w2 = h[i] + 2 * h[i - 1]
            d[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i])

    d[0] = _end_derivative(h[0], h[1], delta[0], delta[1]) if n > 2 else delta[0]
    d[-1] = _end_derivative(h[-1], h[-2], delta[-1], delta[-2]) if n > 2 else delta[-1]
    return d


def pchip_eval(x, y, xq):
    """Evaluate the PCHIP interpolant of (x, y) at scalar xq. x must be increasing."""
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    d = pchip_derivatives(x, y)

    xq_clamped = min(max(xq, x[0]), x[-1])
    i = int(np.searchsorted(x, xq_clamped, side="right") - 1)
    i = min(max(i, 0), len(x) - 2)

    h = x[i + 1] - x[i]
    t = (xq_clamped - x[i]) / h

    h00 = 2 * t**3 - 3 * t**2 + 1
    h10 = t**3 - 2 * t**2 + t
    h01 = -2 * t**3 + 3 * t**2
    h11 = t**3 - t**2

    return h00 * y[i] + h10 * h * d[i] + h01 * y[i + 1] + h11 * h * d[i + 1]
