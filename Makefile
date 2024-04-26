PATH := ~/.solc-select/artifacts/solc-0.8.21:~/.solc-select/artifacts:$(PATH)
certora-ngt     :; PATH=${PATH} certoraRun certora/Ngt.conf$(if $(rule), --rule $(rule),)
certora-mkr-ngt :; PATH=${PATH} certoraRun certora/MkrNgt.conf$(if $(rule), --rule $(rule),)
