#!/usr/bin/env python3
"""
Test trace
"""

def d():
    return 2026

def c():
    return d()

def b():
    return c()

def a():
    return b()

print(a())
