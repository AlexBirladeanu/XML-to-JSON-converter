%{
  #include <stdio.h>
  #include <string.h>
  #include <stdbool.h>
  
  char fieldName[100];
  char fieldValue[100];
  int oldTabsNumber = 0;
  int currentTabsNumber = 0;
  int attributesCounter = 0;
  char currentAttrNames[10][100];
  char currentAttrValues[10][100];
  FILE *fptr;

  typedef struct Element {
    int id;//auto-incremented
    char name[100];
    char value[100];
    char attrNames[10][100];
    char attrValues[10][100];
    struct Element *children[10];
    struct Element *parent;
  } Element;

  Element *root;
  Element *currentParent;
  Element *lastNode;
  Element *searchResult[10];
  int resultIndex = 0;
%}

%union {
  char* svalue;
  int ivalue;
}

%token <svalue> STRING 
%token <svalue> QUERY 
%token <ivalue> VALUE_INTEGER
%token TAB

%type<ivalue> tabs
%type<ivalue> nameAndValue
%%

program : program expression '\n'
        |
	;

expression : 
          tabs nameAndValue {
            currentTabsNumber = $1; 
            updateParent();
            if($2!=0) // is 0 only when the row is just the ending of a element (Ex. </book>)
              addNode();
          }

          | 
          nameAndValue {
            currentTabsNumber = 0; 
            updateParent();
            if($1!=0)
              addNode();
          }  

          | '<' {
            printAll(root, -1);
            fclose(fptr); 
          }

          | query
        ;

nameAndValue: 
              '<' STRING '>' { 
                resetString(fieldName);
                resetString(fieldValue);
                memcpy(fieldName, $2, strlen($2)-2); 
                $$ = 1;
              }

              | '<' STRING attributes '>' { 
                resetString(fieldName);
                resetString(fieldValue);
                for(int i=0; i<strlen($2); i++) {
                  if($2[i]==' ') {
                    break;
                  } else {
                    fieldName[i] = $2[i];
                  }
                }
                $$ = 1;
              }

              | '<' STRING '>' intOrStringValue '<' '/' STRING '>' 
              {
                resetString(fieldName);
                memcpy(fieldName, $7, strlen($7)-1); 
                $$ = 1;
              }

              | '<' STRING attributes '>' intOrStringValue '<' '/' STRING '>' 
              {
                resetString(fieldName);
                memcpy(fieldName, $8, strlen($8)-1); 
                $$ = 1;
              }

              | '<' '/' STRING '>' {
                $$=0;
              }

tabs: TAB {$$ = 1;}
    | tabs tabs {$$ = $1 + $2;}
    ;

intOrStringValue: STRING {
                resetString(fieldValue);
                memcpy(fieldValue, $1, strlen($1));
            }
            | VALUE_INTEGER {
                resetString(fieldValue);
                sprintf(fieldValue, "%d", $1);
            }

attributes: ' ' STRING '=' STRING {
              memcpy(currentAttrNames[attributesCounter], $2, strlen($2) - 1 - strlen($4));
              memcpy(currentAttrValues[attributesCounter], $4, strlen($4));
              attributesCounter++;
            }
            | ' ' STRING '=' VALUE_INTEGER {
              for(int i=0; i<strlen($2); i++) {
                if($2[i]=='=') {
                  break;
                } else {
                  currentAttrNames[attributesCounter][i] = $2[i];
                }
              }
              sprintf(currentAttrValues[attributesCounter], "%d", $4);
              attributesCounter++;
            }
            | attributes attributes
            ;

nodepath: QUERY
      {
          searchNodes($1+6);
      }

query: nodepath {
        printSearchResult();
      }
      | nodepath '[' '@' STRING ']'{
        resetString(fieldName);
        memcpy(fieldName, $4, strlen($4) - 1);
        filterResultsByAttribute(fieldName, "", false);
        printSearchResult();
      }
      | nodepath '[' '@' STRING '=' STRING ']' {
        resetString(fieldName);
        memcpy(fieldName, $4, strlen($4) - 1 - strlen($6));
        resetString(fieldValue);
        memcpy(fieldValue, $6, strlen($6) - 1);
        filterResultsByAttribute(fieldName, fieldValue, true);
        printSearchResult();
      }
      | nodepath '[' STRING '>' VALUE_INTEGER ']' {
        resetString(fieldName);
        for(int i=0; i<strlen($3); i++) {
          if($3[i] == '>') {
            break;
          }
          fieldName[i] = $3[i];
        }
        filterByInt(fieldName, $5);
        printSearchResult();
      }
%%
//============================================================================================================

//============================================================================================================

void addNode() {
  Element* newElement = (Element*)malloc(sizeof(Element));
  resetString(newElement->name);
  resetString(newElement->value);
  strcpy(newElement->name, fieldName);
  strcpy(newElement->value, fieldValue);
  newElement->parent = currentParent;
  if(currentParent !=NULL){
    for(int i=0; i<10; i++) {
      if(currentParent->children[i]==NULL) {
        currentParent->children[i] = newElement;
        break;
      }
    }
  }
  for(int i=0; i<10; i++) {
    newElement->children[i] = NULL;
  }
  static int currentId = 0;
  newElement->id = currentId;
  currentId++;
  for(int i=0; i<attributesCounter; i++) {
    strcpy(newElement->attrNames[i], currentAttrNames[i]);
    strcpy(newElement->attrValues[i], currentAttrValues[i]);
  }
  for(int i=0; i<attributesCounter; i++) {
    resetString(currentAttrNames[i]);
    resetString(currentAttrValues[i]);
  }
  attributesCounter = 0;
  lastNode = newElement;
}

void resetString(char string[]) {
  for(int i=0; i<100; i++) {
    string[i] = '\0';
  }
}

void printTabs(int tabsNumber) {
  for(int i=0; i<tabsNumber; i++) {
    fprintf(fptr, "\t");
    printf("\t");
  }
}

void printAttributes(Element *node, int tabs) {
    for(int i=0; i<10; i++) {
      if(strcmp(node->attrNames[i], "")==0) {
        break;
      } else {
        printTabs(tabs);
        if(i<9 && strcmp(node->attrNames[i+1], "")!=0) {
          printf("%s: %s,\n", node->attrNames[i], node->attrValues[i]);
          fprintf(fptr, "%s: %s,\n", node->attrNames[i], node->attrValues[i]);
        } else {//this is the last attribute
          if(strcmp(node->name, "")!=0) {
            printf("%s: %s,\n", node->attrNames[i], node->attrValues[i]);
            fprintf(fptr, "%s: %s,\n", node->attrNames[i], node->attrValues[i]);
          } else {
            printf("%s: %s\n", node->attrNames[i], node->attrValues[i]);
            fprintf(fptr, "%s: %s\n", node->attrNames[i], node->attrValues[i]);
          }
        }
      }
    }
}

void printChildren(Element *node, int tabs){
	for(int i=0; i<10; i++) {
      if(node->children[i] !=NULL) {
        printAll(node->children[i], tabs);
      } else {
        break;
      }
    }
}

bool hasAttributes(Element* node) {
	if(strcmp(node->attrNames[0], "")==0) {
		return false;
	}
	return true;
}

bool hasChildren(Element* node) {
  if(node->children[0] == NULL) {
    return false;
  }
  return true;
}

bool isFirstElementOfArray(Element* node) {
  if(node == NULL) {
    return false;
  }
	if(strcmp(node->value, "")!=0)
		return false;
	int indexInChildrenArray = 0;
	for(int i=0; i<10; i++) {
		if(node->parent->children[i]->id == node->id) {
			indexInChildrenArray = i;
			break;
		}
	}
	if(indexInChildrenArray == 9) {
		return false;
  }
	if(indexInChildrenArray == 0 || ((indexInChildrenArray > 0) && (strcmp(node->name, node->parent->children[indexInChildrenArray-1]->name)) != 0)) {
    if(node->parent->children[indexInChildrenArray+1] != NULL){
		  if(strcmp(node->name, node->parent->children[indexInChildrenArray+1]->name) == 0) {
			  return true;
		  }
    }
	}
	return false;
}

bool isLastElementOfArray(Element* node) {
  if(node == NULL) {
    return false;
  }
	if(strcmp(node->value, "")!=0)
		return false;
	int indexInChildrenArray = 0;
	for(int i=0; i<10; i++) {
		if(node->parent->children[i]->id == node->id) {
			indexInChildrenArray = i;
			break;
		}
	}
	if(indexInChildrenArray == 0)
		return false;
	if(indexInChildrenArray == 9 || node->parent->children[indexInChildrenArray+1] == NULL) {
    if(node->parent->children[indexInChildrenArray-1] != NULL) {
		  if(strcmp(node->name, node->parent->children[indexInChildrenArray-1]->name) == 0) {
			  return true;
		  }
    }
	} else {
    if(node->parent->children[indexInChildrenArray+1] != NULL) {
      if((indexInChildrenArray < 9) && (strcmp(node->name, node->parent->children[indexInChildrenArray+1]->name)) != 0) {
        if(node->parent->children[indexInChildrenArray-1] != NULL) {
		      if(strcmp(node->name, node->parent->children[indexInChildrenArray-1]->name) == 0) {
			      return true;
		      }
        }
      }
    }
  }
	return false;
}

bool isInMiddleOfArray(Element* node) {
  if(node == NULL) {
    return false;
  }
	int indexInChildrenArray = 0;
	for(int i=0; i<10; i++) {
		if(node->parent->children[i]->id == node->id) {
			indexInChildrenArray = i;
			break;
		}
	}
	Element* first = NULL;
	Element *last = NULL;
	for(int i=0; i<indexInChildrenArray; i++) {
    if(node->parent->children[i] != NULL) {
		  if(isFirstElementOfArray(node->parent->children[i])) {
			  first = node->parent->children[i];
			  break;
		  }
    }
	}
	for(int i=indexInChildrenArray+1; i<10; i++) {
    if(node->parent->children[i] != NULL) {
		  if(isLastElementOfArray(node->parent->children[i])) {
			  last = node->parent->children[i];
			  break;
		  }
    }
	}
	if(first == NULL || last == NULL) {
		return false;
	}
	return true;
}

bool hasRightBrother(Element* node) {
  int indexInChildrenArray = 0;
  for(int i=0; i<10; i++) {
    if(node->id == node->parent->children[i]->id) {
      indexInChildrenArray = i;
      break;
    }
  }
  if(indexInChildrenArray == 9) {
    return false;
  }
  if(node->parent->children[indexInChildrenArray+1] == NULL) {
    return false;
  } else {
    return true;
  }
}

void printAll(Element* node, int tabs) {
	if(node == NULL) {
	  return;
  	}
	if(node->parent==NULL) {//this is the artificial root of the tree, it contains no xml value
		printChildren(node, tabs+1);
		return;
	}
	if(isFirstElementOfArray(node)) {    
		printTabs(tabs);
		printf("%s: [\n", node->name);
		fprintf(fptr, "%s: [\n", node->name);

		printTabs(tabs);
		printf("{\n");
		fprintf(fptr, "{\n");
	}
	else {  
    if(isInMiddleOfArray(node) || isLastElementOfArray(node)) {
		  printTabs(tabs);
		  printf("{\n");
		  fprintf(fptr, "{\n");
    } else {
      if(hasAttributes(node)) {
		    printTabs(tabs);
	  	  printf("%s: {\n", node->name);
	  	  fprintf(fptr, "%s: {\n", node->name);
	    } else {
		    printTabs(tabs);
        if(hasRightBrother(node)) {
   		    printf("%s: %s,\n", node->name, node->value);
   		    fprintf(fptr, "%s: %s,\n", node->name, node->value);
        } else {
   		    printf("%s: %s\n", node->name, node->value);
   		    fprintf(fptr, "%s: %s\n", node->name, node->value);
        }
        if(hasChildren(node)) {
          printTabs(tabs);
          printf("{\n");
          fprintf(fptr, "{\n");
        }
      }
    }
	}
	printAttributes(node ,tabs+1);
  printChildren(node, tabs+1);
	
  if(hasChildren(node)) {
	  printTabs(tabs);
	  printf("}\n");
	  fprintf(fptr, "}\n");
  } else {
    if(hasAttributes(node)) {
      printTabs(tabs+1);
      printf("#text: %s\n", node->value);
      fprintf(fptr, "#text: %s\n", node->value);
      printTabs(tabs);
      printf("}\n");
      fprintf(fptr, "}\n");
    }
  }
	if(isLastElementOfArray(node)) {
		printTabs(tabs);
		printf("]\n");
		fprintf(fptr, "]\n");
	}
}

void updateParent() {
  if(currentTabsNumber > oldTabsNumber) {
    currentParent = lastNode;
  }
  if(currentTabsNumber < oldTabsNumber) {
    currentParent = currentParent->parent;
  }
  oldTabsNumber = currentTabsNumber;
}

void findByName(char nodeName[], Element* root, Element* result[]) {
  if(strcmp(nodeName, root->name)==0) {
    result[resultIndex++] = root;
  }
  for(int i=0; i<10; i++) {
    if(root->children[i] != NULL) {
      findByName(nodeName, root->children[i], result);
    }
  }
}

void checkParent(char parentName[]) {
  for(int i=0; i<resultIndex; i++) {
    if(searchResult[i] == NULL) {
      break;
    }
    if(strcmp(searchResult[i]->parent->name, parentName) != 0) {
      searchResult[i] = NULL;
      for(int j=i; j<resultIndex-1; j++) {
        if(searchResult[j+1] != NULL) {
          searchResult[j] = searchResult[j+1];
        } else {
          searchResult[j] = NULL;
        }
      }
      resultIndex--;
    }
  }
}

void checkAncestor(char ancestorName[]) {
  for(int i=0; i<resultIndex; i++) {
    bool ancestorFound = false;
    Element* ancestor = searchResult[i]->parent;
    while(ancestor != root) {
      if(strcmp(ancestor->name,ancestorName) == 0) {
        ancestorFound = true;
        break;
      }
      ancestor = ancestor->parent;
    }
    if(!ancestorFound) {
      searchResult[i] = NULL;
      for(int j=i; j<resultIndex-1; j++) {
        if(searchResult[j+1] != NULL) {
          searchResult[j] = searchResult[j+1];
        } else {
          searchResult[j] = NULL;
        }
      }
      resultIndex--;
    }
  }
}

void searchNodes(char path[]) {
  /* for(int i=0; i<10; i++) {
    searchResult[i] = NULL;
  } */
  int separators[10]={0}; //use 0 for '', 1 for '/' and 2 for '//'
  int separatorIndex = 0;
  char nodeNames[10][100];
  for(int i=0; i<10; i++) {
    resetString(nodeNames[i]);
  }
  int nodeNameIndex = 0;
  int currentSeparator = 0;
  char currentNodeName[100] = "";

  for(int i=0; i<strlen(path); i++) {
    if(path[i]!='/' && i==0) {
      currentSeparator = 0;
    }
    if(path[i] == '/') {
      if(i<strlen(path) - 1) {
        if(path[i+1] == '/') {
          currentSeparator = 2;
          i+=2;
        } else {
          currentSeparator = 1;
          i++;
        }
      }
    }
    int copyIndex = 0;
    while(i<strlen(path)) {
      currentNodeName[copyIndex++] = path[i];
      if(i<strlen(path)-1 && path[i+1]!='/') {
        i++;
      } else {
        break;
      }
    }
    if(strcmp(currentNodeName, "")==0) {
      continue;
    }
    strcpy(nodeNames[nodeNameIndex++], currentNodeName);
    separators[separatorIndex++] = currentSeparator;
    resetString(currentNodeName);
  }
  findByName(nodeNames[nodeNameIndex-1], root, searchResult);
  for(int i=nodeNameIndex-2; i>=0; i--) {
    if(separators[i+1]==0) {
      continue;
    } 
    if(separators[i+1]==1) {
      checkParent(nodeNames[i]);
    }
    if(separators[i+1]==2) {
      checkAncestor(nodeNames[i]);
      continue;
    }
  }
}

void filterResultsByAttribute(char attrName[], char attrValue[], bool checkValue) {
  for(int i=0; i<resultIndex; i++) {
    printf("i=%d\tresultIndex=%d\n", i, resultIndex);
    if(!hasAttributes(searchResult[i])) {
      printf("NO ATTR DELETE\n");
      searchResult[i] = NULL;
      for(int j=i; j<resultIndex-1; j++) {
        if(searchResult[j+1] != NULL) {
          searchResult[j] = searchResult[j+1];
        } else {
          searchResult[j] = NULL;
        }
      }
      resultIndex--;
      continue;
    }
    bool attributeFound = false;
    for(int j=0; j<10; j++) {
      if(strcmp(searchResult[i]->attrNames[j], "") == 0) {
        break;
      }
      if(checkValue) {
        printf("check value TRUE\n");
        printf("searchResult[%d]->attrNames[%d]=%s\n", i, j, searchResult[i]->attrNames[j]);
        printf("searchResult[%d]->attrValues[%d]=%s\n", i, j, searchResult[i]->attrValues[j]);
        if(strcmp(searchResult[i]->attrNames[j], attrName) == 0 && strcmp(searchResult[i]->attrValues[j], attrValue) == 0) {
          attributeFound = true;
        }
      } else {
        if(strcmp(searchResult[i]->attrNames[j], attrName) == 0) {
          attributeFound = true;
        }
      }
    }
    if(attributeFound == false) {
      printf("DELETE RESUlt NR i=%d\n", i);
      searchResult[i] = NULL;
      for(int j=i; j<resultIndex-1; j++) {
        if(searchResult[j+1] != NULL) {
          searchResult[j] = searchResult[j+1];
        } else {
          searchResult[j] = NULL;
        }
      }
      resultIndex--;
    }
  }
}

bool isNumber(char val[]) {
  for(int i=0; i<strlen(val); i++) {
    if(strchr("0123456789", val[i]) == NULL) {
      return false;
    }
  }
  return true;
}

void filterByInt(char childName[], int lowRange) {
  for(int i=0; i<resultIndex; i++) {
    bool valid = false;
    for(int j=0; j<10; j++)  {
      if(searchResult[i]->children[j] == NULL) {
        break;
      }
      if(strcmp(searchResult[i]->children[j]->name, childName) == 0) {
        if(isNumber(searchResult[i]->children[j]->value)) {
          int intValue = atoi(searchResult[i]->children[j]->value);
          if(intValue > lowRange) {
            valid = true;
          }
        }
      }
    }
    if(valid == false) {
      searchResult[i] = NULL;
      for(int j=i; j<resultIndex-1; j++) {
        if(searchResult[j+1] != NULL) {
          searchResult[j] = searchResult[j+1];
        } else {
          searchResult[j] = NULL;
        }
      }
      resultIndex--;
    }
  }
}

void printSearchResult() {
  for(int i=0; i<resultIndex; i++) {
    if(searchResult[i] == NULL) {
      break;
    }
    printAll(searchResult[i], 1);
  }
}

int main() {
  fptr = fopen("jsonFormat.txt", "w");
  for(int i=0; i<10; i++) {
    resetString(currentAttrNames[i]);
    resetString(currentAttrValues[i]);
  }
  lastNode = NULL;
  addNode("root", "rootValue", NULL);
  root = lastNode;
  currentParent = root;
  yyparse();
  return 0;
}