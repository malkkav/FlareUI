local test = dofile('tools/tests/fixtures/embedded-bag-click.lua')
test.bankScenario(test.keyring)
test.checkItemOnCursor(test.keyring, 'key')
print('PASS: keyring toggles the native backpack across two bank visits and accepts a carried key')
