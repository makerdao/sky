# SKY Token and contract associated

This repository includes 2 smart contracts:

- SKY token
- MkrSky Converter

### SKY token

This is a standard erc20 implementation with regular `permit` functionality + EIP-1271 smart contract signature validation.

### MkrSky

A permissionless converter of `Mkr` to `Sky`.
Upon initialization, an amount of `Sky` equivalent to the total supply of `Mkr` is minted to it.
It is then assumed that further minting of `Mkr` will not happen.
In case the `Sky` amount in the converter later exceeds the `Mkr` supply, governance can use the `burn` function to reduce the `Sky` balance. 
The above can happen for example because of burning of `Mkr` outside of the converters, using the `mkrToSky` path in the old converter, or because of `Sky` donations to the new converter. 

The exchange rate is generally 1:`rate` (value defined as `immutable`), while there is also a configureable fee.
The swap `mkrToSky` function receives `Mkr`, burns it and sends the equivalent amount in `Sky` from the balance, minus the fee.
The accumulated fees can be collected by governance.

### Legacy MkrSky

The legacy MkrSky converter supported bi-directional conversions.
Upon initialization of the new converter, only the `mkrToSky` path will be supported.
It is expected that once the new converter fee becomes non-zero, the `mkrToSky` path in the old converter will also be disabled.
