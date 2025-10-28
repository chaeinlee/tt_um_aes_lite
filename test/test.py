# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

async def wait_for_ready(dut, timeout=1000):
    """Wait for the ready signal (uio_out[0]) to go high"""
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if int(dut.uio_out.value) & 0x01:  # Check bit 0 (ready signal)
            return True
    return False

async def run_aes_test(dut, data, key, test_name):
    """Run a single AES encryption test"""
    dut._log.info(f"=== {test_name}: Data=0x{data:02X}, Key=0x{key:02X} ===")
    
    # Reset
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    # Set input values
    dut.ui_in.value = data
    dut.uio_in.value = key
    
    # Wait for encryption to complete
    ready = await wait_for_ready(dut, timeout=1000)
    
    if ready:
        result = dut.uo_out.value
        dut._log.info(f"Result: 0x{result:02X}")
        return result
    else:
        dut._log.error(f"Timeout waiting for ready signal!")
        return None

@cocotb.test()
async def test_project(dut):
    dut._log.info("Starting AES Test...")
    
    # Set the clock period to 10 ns (100 MHz)
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Initial reset
    dut._log.info("Initial Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    
    # Test 1: Data=0xAA, Key=0x55
    result1 = await run_aes_test(dut, 0xAA, 0x55, "Test 1")
    
    # Test 2: Data=0x12, Key=0x34
    result2 = await run_aes_test(dut, 0x12, 0x34, "Test 2")
    
    # Test 3: Data=0xFF, Key=0xFF
    result3 = await run_aes_test(dut, 0xFF, 0xFF, "Test 3")
    
    # Test 4: Data=0x00, Key=0x00
    result4 = await run_aes_test(dut, 0x00, 0x00, "Test 4")
    
    # Test 5: Pattern Test Data=0x5A, Key=0xA5
    result5 = await run_aes_test(dut, 0x5A, 0xA5, "Test 5")
    
    # Verify all tests completed
    assert result1 is not None, "Test 1 failed to complete"
    assert result2 is not None, "Test 2 failed to complete"
    assert result3 is not None, "Test 3 failed to complete"
    assert result4 is not None, "Test 4 failed to complete"
    assert result5 is not None, "Test 5 failed to complete"
    
    dut._log.info("All tests complete!")
    
    # Wait a bit before finishing
    await ClockCycles(dut.clk, 20)
