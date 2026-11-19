local test = dofile('tools/tests/fixtures/embedded-bag-click.lua')
test.allBagsKeyScenario(test.reagent)
print('PASS: Open All Bags closes the backpack opened via the reagent slot, then reopens all bags')
