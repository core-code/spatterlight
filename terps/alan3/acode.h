#ifndef _ACODE_H_
#define _ACODE_H_

#define ACODEEXTENSION ".a3c"

/* Basic types */
#include <stddef.h>
#include <stdint.h>

typedef uint32_t Aptr;       /* Type for an ACODE pointer used in the structures */
/* Aptrs are 32 bit to fit into the 32-bit structure of the Amachine,
   but represents a *real* pointer value, which on 64-bit machines are
   64bits. So an Aptr is a symbolic value for the actual address and
   has to be translated through fromAptr() in memory.c
 */

typedef uint32_t Aword;      /* Type for an ACODE word */
typedef uint32_t Aaddr;      /* Type for an ACODE address in Amemory */
typedef uint32_t Aid;        /* Type for an ACODE Instance Id value */
typedef uint32_t Abool;      /* Type for an ACODE Boolean value */
typedef uint32_t Aset;       /* Type for an ACODE Set value */
typedef int32_t Aint;        /* Type for an ACODE Integer value */
typedef int32_t CodeValue;   /* Definition for the packing process */


/* Constants for the Acode file, words/block & bytes/block */
#define BLOCKLEN 256L
#define BLOCKSIZE (BLOCKLEN*sizeof(Aword))


/* Definitions for the packing process */
#define VALUEBITS 16

#define EOFChar 256
#define TOPVALUE (((CodeValue)1<<VALUEBITS) - 1) /* Highest value possible */

/* Half and quarter points in the code value range */
#define ONEQUARTER (TOPVALUE/4+1)	/* Point after first quarter */
#define HALF (2*ONEQUARTER)		/* Point after first half */
#define THREEQUARTER (3*ONEQUARTER)	/* Point after third quarter */


/* AMACHINE Word Classes, bit positions */
typedef int WordKind;
#define  SYNONYM_WORD 0
#define  SYNONYM_BIT (((Aword)1)<<SYNONYM_WORD)

#define  ADJECTIVE_WORD (SYNONYM_WORD+1)
#define  ADJECTIVE_BIT (((Aword)1)<<ADJECTIVE_WORD)

#define  ALL_WORD (ADJECTIVE_WORD+1)
#define  ALL_BIT (((Aword)1)<<ALL_WORD)

#define  EXCEPT_WORD (ALL_WORD+1)
#define  EXCEPT_BIT (((Aword)1)<<EXCEPT_WORD)

#define  CONJUNCTION_WORD (EXCEPT_WORD+1)
#define  CONJUNCTION_BIT (((Aword)1)<<CONJUNCTION_WORD)

#define  PREPOSITION_WORD (CONJUNCTION_WORD+1)
#define  PREPOSITION_BIT (((Aword)1)<<PREPOSITION_WORD)

#define  DIRECTION_WORD (PREPOSITION_WORD+1)
#define  DIRECTION_BIT (((Aword)1)<<DIRECTION_WORD)

#define  IT_WORD (DIRECTION_WORD+1)
#define  IT_BIT (((Aword)1)<<IT_WORD)

#define  NOISE_WORD (IT_WORD+1)
#define  NOISE_BIT (((Aword)1)<<NOISE_WORD)

#define  NOUN_WORD (NOISE_WORD+1)
#define  NOUN_BIT (((Aword)1)<<NOUN_WORD)

#define  THEM_WORD (NOUN_WORD+1)
#define  THEM_BIT (((Aword)1)<<THEM_WORD)

#define  VERB_WORD (THEM_WORD+1)
#define  VERB_BIT (((Aword)1)<<VERB_WORD)

#define  PRONOUN_WORD (VERB_WORD+1)
#define  PRONOUN_BIT (((Aword)1)<<PRONOUN_WORD)

#define  WRD_CLASSES (PRONOUN_WORD+1)


/* The #nowhere and NO_LOCATION constants */
#define NO_LOCATION 0
#define NOWHERE 1


/* Syntax element classifications */
#define EOS (-2)		/* End Of Syntax */

/* Syntax element flag bits */
#define MULTIPLEBIT 0x1
#define OMNIBIT 0x2


/* Parameter Classes */
typedef enum ClaKind {		/* NOTE! These must have the same order as */
    CLA_OBJ = 1,			/* the name classes in NAM.H */
    CLA_CNT = (int)CLA_OBJ<<1,
    CLA_ACT = (int)CLA_CNT<<1,
    CLA_NUM = (int)CLA_ACT<<1,
    CLA_STR = (int)CLA_NUM<<1,
    CLA_COBJ = (int)CLA_STR<<1,
    CLA_CACT = (int)CLA_COBJ<<1
} ClaKind;


/* Verb Qualifiers */
typedef enum QualClass {
    Q_DEFAULT,
    Q_AFTER,
    Q_BEFORE,
    Q_ONLY
} QualClass;


/* The AMACHINE Operations */
typedef enum OpClass {
    C_CONST,
    C_STMOP,
    C_CURVAR
} OpClass;

/* AMACHINE Text Styles */
typedef enum TextStyle {
    NORMAL_STYLE,
    EMPHASIZED_STYLE,
    PREFORMATTED_STYLE,
    ALERT_STYLE,
    QUOTE_STYLE
} TextStyle;


#define CONSTANT(op) ((Aword)op)
#define INSTRUCTION(op) ((((Aword)C_STMOP)<<28)|((Aword)op))
#define CURVAR(op) ((((Aword)C_CURVAR)<<28)|((Aword)op))

typedef enum InstClass {
    I_LINE,                    /* Source line debug info */
    I_PRINT,                   /* Print a string from the text file */
    I_STYLE,                   /* Set output text style */
    I_QUIT,
    I_LOOK,
    I_SAVE,
    I_RESTORE,
    I_LIST,                     /* List contents of a container */
    I_EMPTY,
    I_SCORE,
    I_VISITS,
    I_SCHEDULE,
    I_CANCEL,
    I_LOCATE,
    I_MAKE,                     /* Set a boolean attribute to the */
                                /* value on top of stack */
    I_SET,                      /* Set a numeric attribute to the */
                                /* value on top of stack */
    I_SETSTR,                   /* Set a string valued attribute to */
                                /* the string on top of stack, */
                                /* deallocate current contents first */
    I_SETSET,                   /* Set a Set valued attribute to */
                                /* the Set on top of stack, */
                                /* deallocate current contents first */
    I_NEWSET,                   /* Push a new, empty set at the top of stack */
    I_ATTRIBUTE,                /* Push the value of an attribute */
    I_ATTRSTR,                  /* Push a copy of a string attribute */
    I_ATTRSET,                  /* Push a copy of a set attribute */
    I_UNION,                    /* Add a set from the top of stack to a */
                                /* set valued attribute */
    I_GETSTR,                   /* Get a string contents from text
                                   file, create a copy and push it
                                   on top of stack */
    I_INCR,                     /* Increase an attribute */
    I_DECR,                     /* Decrease a numeric attribute */
    I_INCLUDE,                  /* Include a value in the set on stack top */
    I_EXCLUDE,                  /* Remove a value from the set on stack top */
    I_SETSIZE,                  /* Push number of members in a set */
    I_SETMEMB,                  /* Push the member with index <top>-1
                                   from set <top> */
    I_CONTSIZE,                 /* Push number of members in a container */
    I_CONTMEMB,                 /* Push the member with index <top>-1
                                   from container <top> */
    I_USE,
    I_STOP,
    I_AT,
    I_IN,
    I_INSET,
    I_HERE,
    I_NEARBY,
    I_NEAR,
    I_WHERE,                    /* Current position of an instance */
    I_LOCATION,                 /* The *location* an instance is at */
    I_DESCRIBE,
    I_SAY,
    I_SAYINT,
    I_SAYSTR,
    I_IF,
    I_ELSE,
    I_ENDIF,
    I_AND,
    I_OR,
    I_NE,
    I_EQ,
    I_STREQ,			/* String compare */
    I_STREXACT,			/* Exact match */
    I_LE,
    I_GE,
    I_LT,
    I_GT,
    I_PLUS,
    I_MINUS,
    I_MULT,
    I_DIV,
    I_NOT,
    I_UMINUS,
    I_RND,
    I_RETURN,
    I_SYSTEM,
    I_RESTART,
    I_BTW,
    I_CONTAINS,
    I_DUP,
    I_DEPEND,
    I_DEPCASE,
    I_DEPEXEC,
    I_DEPELSE,
    I_ENDDEP,
    I_ISA,
    I_FRAME,
    I_SETLOCAL,
    I_GETLOCAL,
    I_ENDFRAME,
    I_LOOP,
    I_LOOPNEXT,
    I_LOOPEND,
    I_SUM,                /* Aggregates: */
    I_MAX,
    I_MIN,
    I_COUNT,              /* COUNT aggregate & limit meta-attribute */
    I_SHOW,
    I_PLAY,
    I_CONCAT,
    I_STRIP,
    I_POP,
    I_TRANSCRIPT,
    I_DUPSTR              /* Duplicate the string on the top of the stack */
} InstClass;

typedef enum SayForm {
    SAY_SIMPLE,
    SAY_DEFINITE,
    SAY_INDEFINITE,
    SAY_NEGATIVE,
    SAY_PRONOUN
} SayForm;

typedef enum VarClass {
    V_PARAM,
    V_CURLOC,
    V_CURACT,
    V_CURVRB,
    V_SCORE,
    V_CURRENT_INSTANCE,
    V_MAX_INSTANCE
} VarClass;

/* For transitivity in HERE, IN etc. */
typedef enum {
    TRANSITIVE = 0,
    DIRECT = 1,
    INDIRECT = 2
} ATrans;

/* Predefined attributes, one is for containers and the other for locations
   and since instances cannot be both, the attributes can have the same number */
#define OPAQUEATTRIBUTE 1
#define VISITSATTRIBUTE 1
#define PREDEFINEDATTRIBUTES OPAQUEATTRIBUTE

#define I_CLASS(x) ((x)>>28)
#define I_OP(x)    ((x&0x08000000)?(x)|0xf0000000:(x)&0x0fffffff)


/* AMACHINE Table entry types */

#define AwordSizeOf(x) (sizeof(x)/sizeof(Aword))

typedef struct ArticleEntry {
    Aaddr address;		/* Address of article code */
    Abool isForm;		/* Is the article a complete form? */
} ArticleEntry;

typedef struct ClassEntry {	/* CLASS TABLE */
    Aword code;             /* Own code */
    Aaddr id;               /* Address to identifier string */
    Aint parent;            /* Code for the parent class, 0 if none */
    Aaddr name;             /* Address to name printing code */
    Aint pronoun;           /* Code for the pronoun word */
    Aaddr initialize;		/* Address to initialization statements */
    Aaddr descriptionChecks;     /* Address of description checks */
    Aaddr description;           /* Address of description code */
    ArticleEntry definite;       /* Definite article entry */
    ArticleEntry indefinite;     /* Indefinite article entry */
    ArticleEntry negative;       /* Negative article entry */
    Aaddr mentioned;		/* Address of code for Mentioned clause */
    Aaddr verbs;            /* Address of verb table */
    Aaddr entered;          /* Address of code for Entered clause */
} ClassEntry;

typedef struct InstanceEntry {	/* INSTANCE TABLE */
    Aint code;                  /* Own code */
    Aaddr id;                   /* Address to identifier string */
    Aint parent;                /* Code for the parent class, 0 if none */
    Aaddr name;                 /* Address to name printing code */
    Aint pronoun;               /* Word code for the pronoun */
    Aint initialLocation;       /* Code for current location */
    Aaddr initialize;           /* Address to initialization statements */
    Aint container;             /* Code for a possible container property */
    Aaddr initialAttributes;	/* Address of attribute list */
    Aaddr checks;               /* Address of description checks */
    Aaddr description;          /* Address of description code */
    ArticleEntry definite;      /* Definite article entry */
    ArticleEntry indefinite;    /* Indefinite article entry */
    ArticleEntry negative;      /* Negative article entry */
    Aaddr mentioned;            /* Address to short description code */
    Aaddr verbs;                /* Address of local verb list */
    Aaddr entered;              /* Address of entered code (location only) */
    Aaddr exits;                /* Address of exit list */
} InstanceEntry;

typedef struct AttributeEntry {	/* ATTRIBUTE LIST */
    Aint code;                  /* Its code */
    Aptr value;                 /* Its value, a string has a dynamic
                                   string pointer, a set has a pointer
                                   to a dynamically allocated set */
    Aaddr id;                   /* Address to the name */
} AttributeEntry;

typedef struct AttributeHeaderEntry {	/* ATTRIBUTE LIST in header */
    Aint code;                          /* Its code */
    Aword value;                /* Its value, a string has a dynamic
                                   string pointer, a set has a pointer
                                   to a dynamically allocated set */
    Aaddr id;                   /* Address to the name */
} AttributeHeaderEntry;

typedef struct ExitEntry {	/* EXIT TABLE structure */
    Aword code;             /* Direction code */
    Aaddr checks;           /* Address of check table */
    Aaddr action;           /* Address of action code */
    Aword target;           /* Id for the target location */
} ExitEntry;


typedef struct RuleEntry {      /* RULE TABLE */
  Abool alreadyRun;
  Aaddr exp;                    /* Address to expression code */
  Aaddr stms;                   /* Address to run */
} RuleEntry;


#define RESTRICTIONCLASS_CONTAINER (-2)
#define RESTRICTIONCLASS_INTEGER (-3)
#define RESTRICTIONCLASS_STRING (-4)

typedef struct RestrictionEntry { /* PARAMETER RESTRICTION TABLE */
    Aint parameterNumber;         /* Parameter number */
    Aint class;                   /* Parameter class code */
    Aaddr stms;                   /* Exception statements */
} RestrictionEntry;

typedef struct ContainerEntry {	/* CONTAINER TABLE */
    Aword owner;                /* Owner instance index */
    Aint class;                 /* Class to allow in container */
    Aaddr limits;               /* Address to limit check code */
    Aaddr header;               /* Address to header code */
    Aaddr empty;                /* Address to code for header when empty */
    Aaddr extractChecks;        /* Address to check before extracting */
    Aaddr extractStatements;    /* Address to execute when extracting */
} ContainerEntry;


typedef struct ElementEntry {	/* SYNTAX ELEMENT TABLES */
    Aint code;                  /* Code for this element, 0 -> parameter */
    Aword flags;                /* Flags for multiple/omni (if parameter), syntax number/verb of EOS */
    Aaddr next;                 /* Address to next element table ... */
                                /* ... or restrictions if code == EOS */
} ElementEntry;

typedef struct SyntaxEntryPreBeta2 {	/* SYNTAX TABLE */
    Aint code;                          /* Code for verb word */
    Aaddr elms;                         /* Address to element tables */
} SyntaxEntryPreBeta2;

typedef struct SyntaxEntry {     /* SYNTAX TABLE */
    Aint code;                   /* Code for verb word, or 0 if starting with parameter */
    Aaddr elms;                  /* Address to element tables */
    Aaddr parameterNameTable;    /* Address to a table of id-addresses giving the names of the parameters */
} SyntaxEntry;

typedef struct ParameterMapEntry {	/* PARAMETER MAPPING TABLE */
    Aint syntaxNumber;
    Aaddr parameterMapping;
    Aint verbCode;
} ParameterMapEntry;

typedef struct EventEntry {	/* EVENT TABLE */
    Aaddr id;                   /* Address to name string */
    Aaddr code;
} EventEntry;

typedef struct ScriptEntry {	/* SCRIPT TABLE */
    Aaddr id;                   /* Address to name string */
    Aint code;			/* Script number */
    Aaddr description;		/* Optional description statements */
    Aaddr steps;		/* Address to steps */
} ScriptEntry;

typedef struct StepEntry {	/* STEP TABLE */
    Aaddr after;		/* Expression to say after how many ticks? */
    Aaddr exp;			/* Expression to condition saying when */
    Aaddr stms;			/* Address to the actual code */
} StepEntry;

typedef struct AltEntry {	/* VERB ALTERNATIVE TABLE */
    Aword qual;			/* Verb execution qualifier */
    Aint param;			/* Parameter number */
    Aaddr checks;		/* Address of the check table */
    Aaddr action;		/* Address of the action code */
} AltEntry;

typedef struct SourceFileEntry { /* SOURCE FILE NAME TABLE */
    Aint fpos;
    Aint len;
} SourceFileEntry;

typedef struct SourceLineEntry { /* SOURCE LINE TABLE */
    Aint file;
    Aint line;
} SourceLineEntry;

typedef struct StringInitEntry { /* STRING INITIALISATION TABLE */
    Aword fpos;                  /* File position */
    Aword len;                   /* Length */
    Aint instanceCode;           /* Where to store it */
    Aint attributeCode;
} StringInitEntry;

typedef struct SetInitEntry {	/* SET INITIALISATION TABLE */
    Aint size;                  /* Size of the initial set */
    Aword setAddress;           /* Address to the initial set */
    Aint instanceCode;          /* Where to store it */
    Aint attributeCode;
} SetInitEntry;

typedef struct DictionaryEntry { /* Dictionary */
    Aaddr string;                /* ACODE address to string */
    Aword classBits;             /* Word class */
    Aword code;
    Aaddr adjectiveRefs;        /* Address to reference list */
    Aaddr nounRefs;             /* Address to reference list */
    Aaddr pronounRefs;          /* Address to reference list */
} DictionaryEntry;

typedef struct IfidEntry {      /* IFIDs are (name, value) pairs */
    Aaddr nameAddress;
    Aaddr valueAddress;
} IfidEntry;



/* AMACHINE Header */

typedef struct ACodeHeader {
    /* Important info */
    char tag[4];                /* "ALAN" */
    char version[4];            /* Version of compiler */
    Aword uid;                  /* Unique id of the compiled game */
    Aword size;                 /* Size of Acode-part of the file in Awords (strings are stored after) */
    /* Options */
    Abool pack;                  /* Is the text packed and encoded ? */
    Aword stringOffset;          /* Offset to string data in game file */
    Aword pageLength;            /* Length of a displayed page */
    Aword pageWidth;             /* and width */
    Aword debug;                 /* Option: debug? */
    /* Data structures */
    Aaddr classTableAddress;
    Aword classMax;             /* 10 */
    Aword entityClassId;
    Aword thingClassId;
    Aword objectClassId;
    Aword locationClassId;
    Aword actorClassId;
    Aword literalClassId;
    Aword integerClassId;
    Aword stringClassId;
    Aaddr instanceTableAddress;	/* Instance table */
    Aword instanceMax;          /* 20 - Highest number of an instance */
    Aword theHero;              /* The hero instance code (id) */
    Aaddr containerTableAddress;
    Aword containerMax;
    Aaddr scriptTableAddress;
    Aword scriptMax;
    Aaddr eventTableAddress;
    Aword eventMax;
    Aaddr syntaxTableAddress;
    Aaddr parameterMapAddress;
    Aword syntaxMax;            /* 30 */
    Aaddr dictionary;
    Aaddr verbTableAddress;
    Aaddr ruleTableAddress;
    Aaddr messageTableAddress;
    /* Miscellaneous */
    Aint attributesAreaSize;	/* Size of attribute data area in Awords */
    Aint maxParameters;         /* Maximum number of parameters in any syntax */
    Aaddr stringInitTable;      /* String init table address */
    Aaddr setInitTable;         /* Set init table address */
    Aaddr start;                /* Address to Start code */
    Aword maximumScore;         /* 40 - Maximum score */
    Aaddr scores;               /* Score table */
    Aint scoreCount;            /* Max index into scores table */
    Aaddr sourceFileTable;      /* Table of fpos/len for source filenames */
    Aaddr sourceLineTable;      /* Table of available source lines to break on */
    Aaddr freq;                 /* Address to Char freq's for coding */
    Aword acdcrc;               /* 46 - Checksum for acd code (excl. hdr) */
    Aword txtcrc;               /* Checksum for text data file, not used */
    Aaddr ifids;                /* 48 - Address to IFIDS */
    Aaddr prompt;
} ACodeHeader;

typedef struct Pre3_0beta2Header {
    /* Important info */
    char tag[4];              /* "ALAN" */
    char version[4];          /* Version of compiler */
    Aword uid;                /* Unique id of the compiled game */
    Aword size;               /* Size of ACD-file in Awords */
    /* Options */
    Abool pack;               /* Is the text packed ? */
    Aword stringOffset;       /* Offset to string data in game file */
    Aword pageLength;         /* Length of a page */
    Aword pageWidth;          /* and width */
    Aword debug;              /* Option: debug */
    /* Data structures */
    Aaddr classTableAddress;  /* Class table */
    Aword classMax;           /* Number of classes */
    Aword entityClassId;
    Aword thingClassId;
    Aword objectClassId;
    Aword locationClassId;
    Aword actorClassId;
    Aword literalClassId;
    Aword integerClassId;
    Aword stringClassId;
    Aaddr instanceTableAddress;	/* Instance table */
    Aword instanceMax;          /* Highest number of an instance */
    Aword theHero;              /* The hero instance code (id) */
    Aaddr containerTableAddress;
    Aword containerMax;
    Aaddr scriptTableAddress;
    Aword scriptMax;
    Aaddr eventTableAddress;
    Aword eventMax;
    Aaddr syntaxTableAddress;
    Aaddr parameterMapAddress;
    Aword syntaxMax;
    Aaddr dictionary;
    Aaddr verbTableAddress;
    Aaddr ruleTableAddress;
    Aaddr messageTableAddress;
    /* Miscellaneous */
    Aint attributesAreaSize;    /* Size of attribute data area in Awords */
    Aint maxParameters;         /* Maximum number of parameters in any syntax */
    Aaddr stringInitTable;      /* String init table address */
    Aaddr setInitTable;         /* Set init table address */
    Aaddr start;                /* Address to Start code */
    Aword maximumScore;         /* Maximum score */
    Aaddr scores;               /* Score table */
    Aint scoreCount;            /* Max index into scores table */
    Aaddr sourceFileTable;      /* Table of fpos/len for source filenames */
    Aaddr sourceLineTable;      /* Table of available source lines to break on */
    Aaddr freq;                 /* Address to Char freq's for coding */
    Aword acdcrc;               /* Checksum for acd code (excl. hdr) */
    Aword txtcrc;               /* Checksum for text data file */
    Aaddr ifids;                /* Address to IFIDS */
} Pre3_0beta2Header;

typedef struct Pre3_0alpha5Header {
    /* Important info */
    char tag[4];              /* "ALAN" */
    char version[4];          /* Version of compiler */
    Aword uid;                /* Unique id of the compiled game */
    Aword size;               /* Size of ACD-file in Awords */
    /* Options */
    Abool pack;               /* Is the text packed ? */
    Aword stringOffset;       /* Offset to string data in game file */
    Aword pageLength;         /* Length of a page */
    Aword pageWidth;          /* and width */
    Aword debug;              /* Option: debug */
    /* Data structures */
    Aaddr classTableAddress;  /* Class table */
    Aword classMax;           /* Number of classes */
    Aword entityClassId;
    Aword thingClassId;
    Aword objectClassId;
    Aword locationClassId;
    Aword actorClassId;
    Aword literalClassId;
    Aword integerClassId;
    Aword stringClassId;
    Aaddr instanceTableAddress;	/* Instance table */
    Aword instanceMax;          /* Highest number of an instance */
    Aword theHero;              /* The hero instance code (id) */
    Aaddr containerTableAddress;
    Aword containerMax;
    Aaddr scriptTableAddress;
    Aword scriptMax;
    Aaddr eventTableAddress;
    Aword eventMax;
    Aaddr syntaxTableAddress;
    Aaddr parameterMapAddress;
    Aword syntaxMax;
    Aaddr dictionary;
    Aaddr verbTableAddress;
    Aaddr ruleTableAddress;
    Aaddr messageTableAddress;
    /* Miscellaneous */
    Aint attributesAreaSize;    /* Size of attribute data area in Awords */
    Aint maxParameters;         /* Maximum number of parameters in any syntax */
    Aaddr stringInitTable;      /* String init table address */
    Aaddr setInitTable;         /* Set init table address */
    Aaddr start;                /* Address to Start code */
    Aword maximumScore;         /* Maximum score */
    Aaddr scores;               /* Score table */
    Aint scoreCount;            /* Max index into scores table */
    Aaddr sourceFileTable;      /* Table of fpos/len for source filenames */
    Aaddr sourceLineTable;      /* Table of available source lines to break on */
    Aaddr freq;                 /* Address to Char freq's for coding */
    Aword acdcrc;               /* Checksum for acd code (excl. hdr) */
    Aword txtcrc;               /* Checksum for text data file */
} Pre3_0alpha5Header;

/* Error message numbers */
typedef enum MsgKind {
    M_UNKNOWN_WORD,
    M_WHAT,
    M_WHAT_WORD,
    M_MULTIPLE,
    M_NOUN,
    M_AFTER_BUT,
    M_BUT_ALL,
    M_NOT_MUCH,
    M_WHICH_ONE_START,
    M_WHICH_ONE_COMMA,
    M_WHICH_ONE_OR,
    M_NO_SUCH,
    M_NO_WAY,
    M_CANT0,
    M_SEE_START,
    M_SEE_COMMA,
    M_SEE_AND,
    M_SEE_END,
    M_CONTAINS,
    M_CARRIES,
    M_CONTAINS_COMMA,
    M_CONTAINS_AND,
    M_CONTAINS_END,
    M_EMPTY,
    M_EMPTYHANDED,
    M_CANNOTCONTAIN,
    M_SCORE,
    M_MORE,
    M_AGAIN,
    M_SAVEWHERE,
    M_SAVEOVERWRITE,
    M_SAVEFAILED,
    M_RESTOREFROM,
    M_SAVEMISSING,
    M_NOTASAVEFILE,
    M_SAVEVERS,
    M_SAVENAME,
    M_REALLY,
    M_QUITACTION,
    M_UNDONE,
    M_NO_UNDO,
    M_WHICH_PRONOUN_START,
    M_WHICH_PRONOUN_FIRST,
    M_IMPOSSIBLE_WITH,
    M_CONTAINMENT_LOOP,
    M_CONTAINMENT_LOOP2,
    MSGMAX
} MsgKind;

#define NO_MSG MSGMAX

#endif
