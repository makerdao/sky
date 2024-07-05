# NGT Token and contract associated

This repository includes 2 smart contracts:

- NGT token
- MkrNgt Converter

### NGT token

This is a standard erc20 implementation with regular `permit` functionality + EIP-1271 smart contract signature validation.
In principle `PauseProxy` and `MkrNgt` would be the only two contracts set as `wards(address)`.

### MkrNgt

It is a converter between `Mkr` and `Ngt` (both ways). Using the `mint` and `burn` capabilities of both tokens it is possible to exchange one to the other. The exchange rate is 1:`rate` (value defined as `immutable`).

**Note:** if one of the tokens removes `mint` capabilities to this contract, it means that the path which gives that token to the user won't be available.

**Note 2:** In the MKR -> NGT conversion, if the user passes a `wad` amount not multiple of `rate`, it causes that a dusty value will be lost. 

## Sherlock Contest:

You can find general (and particular for this repository) scope, definitions, rules, disclaimers and known issues that apply to the Sherlock contest [here](https://github.com/makerdao/sherlock-contest/blob/master/README.md).
Content listed there should be regarded as if it was in this readme.
