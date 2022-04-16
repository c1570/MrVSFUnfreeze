<?php
  // modified version of vsfReanimator
  // https://sourceforge.net/p/viceplus/code/HEAD/tree/trunk/tools/vsfReanimator/vsfReanimator.php

  function word($word) {
    return chr($word & 0xff) . chr($word >> 8);
  }

  function writeToMem($startaddr, $what) {
    global $curaddr;
    global $error;
    $len = strlen($what);
    if($len>127) $error .= "FATAL: Internal error (writeToMem)";
    $ret = '';
    if($len == 1) {
      $ret .= "\xa9" . $what;               // LDA #...
      $ret .= "\x8d" . word($startaddr);    // STA $...
    } else {
      $ret .= "\xa2" . chr($len - 1);       // LDX #...
      $ret .= "\xbd" . word($curaddr + 13); // LDA $(data),x
      $ret .= "\x9d" . word($startaddr);    // STA $startaddr,x
      $ret .= "\xca";                       // DEX
      $ret .= "\x10\xf7";                   // BPL loop
      $ret .= "\x30" . chr($len);           // BMI next (skip data)
      $ret .= $what;                        // DATA
    }
    $curaddr += strlen($ret);
    return $ret;
  }

  function waitForRaster($line) {
    global $curaddr;
    $ret = '';
    $ret .= "\xad\x11\xd0";               // LDA $D011
    if($line>255)
      $ret .= "\x10\xfb";                 // BPL (back)
    else
      $ret .= "\x30\xfb";                 // BMI (back)
    $ret .= "\xad\x12\xd0";               // LDA $D012
    $ret .= "\xc9" . chr($line & 0xff);   // CMP #(linelo)
    $ret .= "\xd0\xf4";                   // BNE (back)
    $curaddr += strlen($ret);
    return $ret;
  }

  function reanimate($accu, $xreg, $yreg, $flags, $sp, $jmpto) {
    global $curaddr;
    $ret = '';
    $ret .= "\xa2" . chr($sp);            // LDX #(sp)
    $ret .= "\x9a";                       // TXS
    $ret .= "\xa9" . chr($flags);         // LDA #(flags)
    $ret .= "\x48";                       // PHA
    $ret .= "\xa9" . chr($accu);          // LDA #(accu)
    $ret .= "\xa2" . chr($xreg);          // LDX #(xreg)
    $ret .= "\xa0" . chr($yreg);          // LDY #(yreg)
    $ret .= "\x28";                       // PLP
    $ret .= "\x4c" . word($jmpto);        // JMP (jmpto)
    $curaddr += strlen($ret);
    return $ret;
  }

  function includeData($data) {
    global $curaddr;
    $ret = '';
    $ret .= jump($curaddr + 3 + strlen($data));
    $ret .= $data;
    $curaddr += strlen($data);
    return $ret;
  }

  function jump($dest) {
    global $curaddr;
    $curaddr += 3;
    return "\x4c" . word($dest); // JMP dest
  }

  function getModule($vsf, $modulename, $major, $minor) {
    global $error;
    $i = 0x3a;
    $found = false;
    $modulename .= "\x00";
    $module = "";
    do {
      $modulelen = ord($vsf[$i + 0x12]) + (ord($vsf[$i + 0x13]) << 8) +
                   (ord($vsf[$i + 0x14]) << 16) + (ord($vsf[$i + 0x15]) << 24);
      if(substr($vsf, $i, strlen($modulename)) == $modulename) {
        $found = true;
        $module = substr($vsf, $i, $modulelen);
      } else {
        $i = $i + $modulelen;
      }
    } while (!$found && ($i < strlen($vsf)));
    if(!$found) $error .= "Module $modulename not found!";
    if((ord($module[0x10]) != $major)||(ord($module[0x11]) != $minor))
      $error .= "FATAL: Module $modulename not using version $major/$minor as expected.";
    return $module;
  }

  // Read vsf file
  $filename = $argv[1];
  if(strlen($filename) == 0)
    $filename = $_FILES['vsffile']['tmp_name'];
  $handle = fopen($filename, "rb");
  $vsf = fread($handle, filesize($filename));
  fclose($handle);

  if(!(substr($vsf, 0x15, 3) == "C64")) die("No C64 snapshot file.");

  // Read lower mem
  $mem = getModule($vsf, "C64MEM", 0, 0);
  $addr0OffsetInMem = 0x1a;

  $error = '';

  //TODO handle set IRQ flags properly
  //TODO timing: offset CIA timers/scan line

  $stage3 = '';
  $curaddr = $stage3runaddr = 0x0700;
  // Set $1/$0
  $stage3 .= writeToMem(1, substr($mem, 0x16, 1));
  $stage3 .= writeToMem(0, substr($mem, 0x17, 1));
  // Unmap cartridge
  $stage3 .= writeToMem(0xde00, "\x80");
  // Init CPU
  $cpu = getModule($vsf, "MAINCPU", 1, 1);
  $stage3 .= reanimate(ord($cpu[0x1a]), // Accu
            ord($cpu[0x1b]), // X reg
            ord($cpu[0x1c]), // Y reg
            ord($cpu[0x20]), // Status
            ord($cpu[0x1d]), // Stack pointer
            ord($cpu[0x1e]) + (ord($cpu[0x1f]) << 8)); // Jmpto

  $stage2 = '';
  $curaddr = $stage2runaddr = 0x9c00;
  // Init CIA1
  $cia1 = getModule($vsf, "CIA1", 2, 2);
  $stage2 .= writeToMem(0xdc0d, "\x1f\x00\x00"); // unset irq mask, stop timer
  $stage2 .= writeToMem(0xdc00, substr($cia1, 0x16, 0x23-0x16)); // write regs
  $stage2 .= writeToMem(0xdc0d, chr(ord($cia1[0x23]) | 0x80)); // set irq mask
  $stage2 .= writeToMem(0xdc0e, "\x10\x10"); // load timer value from latch
  if(ord($cia1[0x2a]) != 0) $error .= "Pending interrupts in CIA1 not supported yet.";

  // Init CIA2
  $cia2 = getModule($vsf, "CIA2", 2, 2);
  $stage2 .= writeToMem(0xdd0d, "\x1f\x00\x00"); // unset irq mask, stop timer
  $stage2 .= writeToMem(0xdd00, substr($cia2, 0x16, 0x23-0x16)); // write regs
  $stage2 .= writeToMem(0xdd0d, chr(ord($cia2[0x23]) | 0x80)); // set irq mask
  $stage2 .= writeToMem(0xdd0e, "\x10\x10"); // load timer value from latch
  if(ord($cia2[0x2a]) != 0) $error .= "Pending interrupts in CIA2 not supported yet.";

  // Init VIC
  $vic = getModule($vsf, "VIC-II", 1, 1);
  $regOffsetInVIC = 0x16 + 1119;
  $stage2 .= writeToMem(0xd000, substr($vic, $regOffsetInVIC, 0x2f));
  if(ord($vic[$regOffsetInVIC + 0x19]) != 0) $error .= "Pending interrupts in VICII not supported yet.";

  // Init SID
  $sid = getModule($vsf, "SIDEXTENDED", 1, 4);
  $stage2 .= writeToMem(0xd400, substr($sid, 0x16, 32));

  // Init last part of stack
  $stage2 .= writeToMem(0x1a0, substr($mem, 0x1a0+$addr0OffsetInMem, 6*16));

  // Copy stage 3
  $stage2 .= writeToMem($stage3runaddr, $stage3);

  // Wait for correct raster line
  $stage2 .= waitForRaster(ord($vic[$regOffsetInVIC - 1]) << 8 + ord($vic[$regOffsetInVIC - 2]));

  // CIAs: RUN!
  $stage2 .= writeToMem(0xdc0e, substr($cia1, 0x24, 2)); // set control regs
  $stage2 .= writeToMem(0xdd0e, substr($cia2, 0x24, 2)); // set control regs
  // set latches when running since otherwise high latch value gets written to timer, too (CIA oddity)
  $stage2 .= writeToMem(0xdc04, substr($cia1, 0x26, 4)); // set latches
  $stage2 .= writeToMem(0xdd04, substr($cia2, 0x26, 4)); // set latches

  // Jump to stage 3
  $stage2 .= jump($stage3runaddr);

  echo word($stage2runaddr);
  echo $stage2;
  if($error != "") {
    fwrite(STDERR, "$error\n");
  }

?>
