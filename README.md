[![Documentation Status](https://readthedocs.org/projects/mizuroute/badge/?version=develop)](https://mizuroute.readthedocs.io/en/develop/?badge=develop)

Installation instruction refers to [here](https://github.com/ESCOMP/mizuRoute/tree/cesm-coupling)

Updates:
01/01/23: solves issue with water injection (previously injection is not allowed because the flow is negative and is forced to 0)
05/11/23: for lake routing, add one parameter D03_MinStorage because upon checking, most lakes/reservoirs have a threshold beyond which outflow starts to rise. This parameter defaults to zero.