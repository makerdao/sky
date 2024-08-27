PATH := ~/.solc-select/artifacts/solc-0.8.21:~/.solc-select/artifacts:$(PATH)
certora-sky     :; PATH=${PATH} certoraRun certora/Sky.conf$(if $(rule), --rule $(rule),)
certora-mkr-sky :; PATH=${PATH} certoraRun certora/MkrSky.conf$(if $(rule), --rule $(rule),)
