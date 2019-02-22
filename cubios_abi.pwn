#include <core>
#include <args>
#include <string>
#include <datagram>

// ABI global constants
#define GUI_ADDR "127.0.0.1:9999"
#define PAWN_PORT_BASE  10000

#define CMD_GUI_BASE    0
#define CMD_GUI_DEBUG   CMD_GUI_BASE+1
#define CMD_FILL        CMD_GUI_BASE+2 /* CMD_FILL,faceN,R,G,B */
#define CMD_BITMAP      CMD_GUI_BASE+3 /* CMD_BITMAP,faceN,resID,X,Y */
#define CMD_PAWN_BASE   100
#define CMD_PAWN_DEBUG  CMD_PAWN_BASE+1
#define CMD_TICK        CMD_PAWN_BASE+2
#define CMD_DETACH      CMD_PAWN_BASE+3
#define CMD_ATTACH      CMD_PAWN_BASE+4 /* CMD_ATTACH, positions matrix here */

#define DISPLAY_PX  240 // 240x240

#define PROJECTION_MAX_X  8
#define PROJECTION_MAX_Y  6

#define CUBES_MAX 8
#define FACES_PER_CUBE 3
#define RIBS_PER_CUBE 4



// Initial "Positions Matrix" 8x6-24 "projection", each node in 2D matrix is {cubeID,faceID}
new const abi_initial_pm[][][] = [
  [[-1,-1], [-1,-1], [ 6, 2], [ 5, 1], [-1,-1], [-1,-1]],
  [[-1,-1], [-1,-1], [ 3, 1], [ 0, 2], [-1,-1], [-1,-1]],
  [[ 6, 1], [ 3, 2], [ 3, 0], [ 0, 0], [ 0, 1], [ 5, 2]],
  [[ 7, 2], [ 2, 1], [ 2, 0], [ 1, 0], [ 1, 2], [ 4, 1]],
  [[-1,-1], [-1,-1], [ 2, 2], [ 1, 1], [-1,-1], [-1,-1]],
  [[-1,-1], [-1,-1], [ 7, 1], [ 4, 2], [-1,-1], [-1,-1]],
  [[-1,-1], [-1,-1], [ 7, 0], [ 4, 0], [-1,-1], [-1,-1]],
  [[-1,-1], [-1,-1], [ 6, 0], [ 5, 0], [-1,-1], [-1,-1]],
]

// "Projection Angle Matrix" 8x6-24, i.e. "how to rotate HW faces to get flat 2D field"
new const abi_pam[PROJECTION_MAX_X][PROJECTION_MAX_Y] = [
  [0,     0,  90, 180,   0,   0],
  [0,     0,   0, 270,   0,   0],
  [90,  180,  90, 180,  90, 180],
  [0,   270,   0, 270,   0, 270],
  [0,     0,  90, 180,   0,   0],
  [0,     0,   0, 270,   0,   0],
  [0,     0,  90, 180,   0,   0],
  [0,     0,   0, 270,   0,   0]
];

// ABI global variables
new abi_cubeN = 0;
new abi_pm[PROJECTION_MAX_X][PROJECTION_MAX_Y][2]; // positions matrix
new abi_attached = 0; // 0 - cubes detached (rotating), 1 - cubes attached

// ABI helpers
abi_LogRcvPkt(const pkt[], size, const src[])
{
  printf("[%s] rcv pkt[%d]: ", src, size);
  for(new i=0; i<size; i++) printf(" %02x", abi_GetPktByte(pkt, i));
  printf("\n");
}

abi_LogSndPkt(const pkt[], size, const cubeN)
{
  printf("[127.0.0.1:%d] snd pkt[%d]: ", PAWN_PORT_BASE+cubeN, size);
  for(new i=0; i<size; i++) printf(" %02x", abi_GetPktByte(pkt, i));
  printf("\n");
}

abi_LogPositionsMatrix()
{
  printf("PM state:\n");

  for(new y=(PROJECTION_MAX_Y-1); y>=0; y--)
  {
    for(new x=0; x<PROJECTION_MAX_X; x++)
    {
      if(abi_pm[x][y][0] == 0xFF) printf("      ");
      else printf("[%d,%d] ", abi_pm[x][y][0], abi_pm[x][y][1]);
    }
    printf("\n");
  }
  printf("\n");
}

abi_GetPktByte(const pkt[], const n)
{
  return ((pkt[n/4] >> (8*(n%4))) & 0xFF);
}

abi_DeserializePositonsMatrix(const pkt[])
{
  for(new x=0; x<PROJECTION_MAX_X; x++)
    for(new y=0; y<PROJECTION_MAX_Y; y++)
      for(new z=0; z<2; z++)
	abi_pm[x][y][z] = abi_GetPktByte(pkt, 1+x*6*2+y*2+z);
}

abi_FacePositionAtProjection(const cubeN, const faceN, &projX, &projY, &projRotAngle)
{
  for(new x=0; x<PROJECTION_MAX_X; x++)
    for(new y=0; y<PROJECTION_MAX_Y; y++)
    {
      if((abi_pm[x][y][0] == cubeN) && (abi_pm[x][y][1] == faceN))
      {
	projX = x; // found!
	projY = y;
	projRotAngle = abi_pam[projX][projY];
	return;
      }
    }
}

abi_InitialFacePositionAtProjection(const cubeN, const faceN, &projX, &projY, &projRotAngle)
{
  for(new x=0; x<PROJECTION_MAX_X; x++)
    for(new y=0; y<PROJECTION_MAX_Y; y++)
    {
      if((abi_initial_pm[x][y][0] == cubeN) && (abi_initial_pm[x][y][1] == faceN))
      {
	projX = x; // found!
	projY = y;
	projRotAngle = abi_pam[projX][projY];
	return;
      }
    }
}

// ABI functions - sends commands to GUI
abi_CMD_FILL(const faceN, const R, const G, const B)
{
  new pkt[2] = 0;
  pkt[0] = (R << 16) | (faceN << 8) | CMD_FILL;
  pkt[1] = (B << 16) | (G & 0x0000FFFF);
  //abi_LogSndPkt(pkt, 2*4, abi_cubeN);
  sendpacket(pkt, 2, GUI_ADDR);
}

abi_CMD_BITMAP(const faceN, const resID, const x, const y)
{
  new pkt[2] = 0;
  pkt[0] = (resID << 16) | (faceN << 8) | CMD_BITMAP;
  pkt[1] = (y << 16) | (x & 0x0000FFFF);
  //abi_LogSndPkt(pkt, 2*4, abi_cubeN);
  sendpacket(pkt, 2, GUI_ADDR);
}

// Process binary commands from GUI
@receivepacket(const packet[], size, const source[])
{
  run(packet, size, source);
}

// This is for run CLI Pawn until key press. Will not be used in MCU version.
@keypressed(key)
{
  exit;
}
