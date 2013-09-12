//--- SPI code

#define SLAVESELECT   10 //ss
#define DATAOUT       11 //MOSI
#define DATAIN        12 //MISO - not used, but part of builtin SPI
#define SPICLOCK      13 //sck

#define NOTEON         9

void SPIInitialize()
{
    byte clr;
    pinMode(DATAOUT, OUTPUT);
    pinMode(DATAIN, INPUT);
    pinMode(SPICLOCK,OUTPUT);
    pinMode(SLAVESELECT,OUTPUT);
    digitalWrite(SLAVESELECT,HIGH); //disable device

    SPCR = (1<<SPE)|(1<<MSTR);
    clr=SPSR;
    clr=SPDR;
    delay(10);
}

char SPITransfer(volatile char data)
{
    SPDR = data; // Start the transmission
    while (!(SPSR & (1<<SPIF))) // Wait the end of the transmission
    {
    };
    return SPDR; // return the received byte
}


//--- MCP42100 code

byte SetPot(int address, int value)
{
    // Slave Select set low to allow commands
    digitalWrite(SLAVESELECT, LOW);

    // 2 byte command
    SPITransfer(0x10 + address); // 0x10 = 'set pot' command
    SPITransfer(value); // Value to set pot

    // Release chip, signal end transfer
    digitalWrite(SLAVESELECT, HIGH); 
}


//--- Sequencer code
// A Bb B C C# D Eb E F Fb G G# A B Bb C C# D Eb E F F# G G# A Bb B C C# D Eb E F F# G G#
byte noteValues[] = { 11, 19, 26, 33, 40, 47, 54, 61, 68, 76, 83, 90, 98, 105, 112, 119, 126, 132, 139, 146, 153, 160, 167, 173, 180, 186, 193, 199, 206, 212, 218, 224, 231, 237, 243, 249 };

void NoteOn( int noteNum )
{
    SetPot(1, noteValues[noteNum]); // Set the resistance for the given note
    digitalWrite(NOTEON, HIGH); // Then turn on the note 
}

void NoteOff()
{
    digitalWrite(NOTEON, LOW); // Turn off the note
}


// Sequencer code

int stepVals[] = {18, 18, 18, 18};  //possible values 0-35, start in the middle.
int activeButton = -1;

#define STEP1_ENABLE 0   // analog
#define STEP2_ENABLE 1   // analog
#define STEP3_ENABLE 2   // analog
#define STEP4_ENABLE 3   // analog

#define SEQUENCER_SPEED 5  // analog

#define STEP_ENABLE_INTERUPT 2 // digital
#define NOTE_SELECT_INTERUPT 3 // digital 

#define STEP1_ENABLEDISPLAY 4  // digital
#define STEP2_ENABLEDISPLAY 5  // digital
#define STEP3_ENABLEDISPLAY 6  // digital
#define STEP4_ENABLEDISPLAY 7  // digital

#define NOTE_SELECT_B 8        // digital


void setup()
{
    // Initialize the SPI interface
    SPIInitialize();

    // Setup the pins appropriately
    pinMode( STEP1_ENABLEDISPLAY, OUTPUT );
    pinMode( STEP2_ENABLEDISPLAY, OUTPUT );
    pinMode( STEP3_ENABLEDISPLAY, OUTPUT );
    pinMode( STEP4_ENABLEDISPLAY, OUTPUT );
    pinMode( STEP_ENABLE_INTERUPT, INPUT);
    pinMode( NOTE_SELECT_INTERUPT, INPUT);


    attachInterrupt( 0, onButton, RISING );
    attachInterrupt( 1, onTurn, CHANGE );

    Serial.begin(9600);
}


// loop() is responsible for playing the notes in the sequence.

void loop()
{
    // Each pass through the loop, play the full sequence of 4 steps
    for (int i = 0; i < 4; i++)
    {
        // Convert the potentiometer hooked to the Speed input into a value between 50ms & 1s 
        int speed = map(analogRead(SEQUENCER_SPEED),0,1023, 5,100)*10;

        // Turn on the given note for 90% of the full note period
        NoteOn(stepVals[i]);
        delay(speed*0.9);

        // Turn the note off for 10% of the full note period
        NoteOff();
        delay(speed*0.1);
    }
}


// onButton() is an interrupt handler that responds when a note-enable button is pressed

void onButton()
{
    // Determine which button was pressed
    int selectedButton;

    if (analogRead(STEP1_ENABLE) > 128)  selectedButton = 1;  
    if (analogRead(STEP2_ENABLE) > 128)  selectedButton = 2;  
    if (analogRead(STEP3_ENABLE) > 128)  selectedButton = 3;  
    if (analogRead(STEP4_ENABLE) > 128)  selectedButton = 4;

    // if that button was already selected, turn it off, otherwise make the 
    // new button the current one
    if (selectedButton == activeButton)
        activeButton = -1;
    else
        activeButton = selectedButton;

    // activate the LED associated with the selected step  
    digitalWrite(STEP1_ENABLEDISPLAY, (activeButton == 1)); 
    digitalWrite(STEP2_ENABLEDISPLAY, (activeButton == 2)); 
    digitalWrite(STEP3_ENABLEDISPLAY, (activeButton == 3)); 
    digitalWrite(STEP4_ENABLEDISPLAY, (activeButton == 4)); 
}


// onTurn() is an interrupt handler that fires when the rotary encoder is turned
void onTurn()
{
    // If no button selected, just discard
    if (activeButton == -1)
        return;
    
    // Get the current value for this step, update it, and write it back
    int currentVal = stepVals[activeButton-1];

    int a = digitalRead(NOTE_SELECT_INTERUPT);
    int b = digitalRead(NOTE_SELECT_B);
  
    if (a == HIGH)   // found a low-to-high on channel A
    {   
    if (b == LOW)    // check channel B to see which way encoder is turning
        currentVal = constrain(currentVal-1,0,35);         // CCW
    else 
        currentVal = constrain(currentVal+1,0,35);         // CW
    }
    else                                        // found a high-to-low on channel A
    { 
    if (b == LOW)    // check channel B to see which way encoder is turning  
        currentVal = constrain(currentVal+1,0,35);          // CW
    else 
        currentVal = constrain(currentVal-1,0,35);          // CCW
    }  
        
    stepVals[activeButton-1] = currentVal;

    /*
    // Output the values to the serial port to display -- commented out for speed, but useful for debugging 
    Serial.print("[ ");
    Serial.print(stepVals[0]);
    Serial.print(" ");
    Serial.print(stepVals[1]);
    Serial.print(" ");
    Serial.print(stepVals[2]);
    Serial.print(" ");
    Serial.print(stepVals[3]);
    Serial.print(" ");
    Serial.println("]");
    */  
}
