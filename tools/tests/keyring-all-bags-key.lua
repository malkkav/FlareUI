local test = dofile('tools/tests/fixtures/embedded-bag-click.lua')
test.allBagsKeyScenario(test.keyring)
print('PASS: Open All Bags closes the backpack opened via the keyring, then reopens all bags')
