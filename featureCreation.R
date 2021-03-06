
rm(list = ls(all = TRUE))
setwd("/home/srishti/workspace")
library(RSQLite)
n <- dbDriver("SQLite", max.con=25)
con <- dbConnect(n, dbname="compData.db")
dbListTables(con)

#Patient
trainingPatient<-dbGetQuery(con, "SELECT * FROM training_patient")
testPatient<-dbGetQuery(con, "SELECT * FROM test_patient")
testPatient$dmIndicator<--1
testPatient<-testPatient[,c(1,6,2:5)]
Patient<-rbind(trainingPatient,testPatient)
rm("testPatient","trainingPatient")
Patient$Gender<-as.factor(Patient$Gender)
# Transcripts
trainingTranscript<-dbGetQuery(con, "SELECT * FROM training_transcript")
testTranscript<-dbGetQuery(con, "SELECT * FROM test_transcript")
Transcript<-rbind(trainingTranscript,testTranscript)
#Transcript<-rbind(trainingTranscript[-1,],testTranscript[-1,])
rm("trainingTranscript","testTranscript")

Transcript$Height<-as.numeric(Transcript$Height)
Transcript$Weight<-as.numeric(Transcript$Weight)

# Clean weight & height outliers. NA for unknown, 0 for typo error
Transcript$Weight[Transcript$Weight==0]<-NA
Transcript$Weight[Transcript$Weight < 85]<-0
Transcript$Weight[Transcript$Weight > 320]<-0
Transcript$Height[Transcript$Height < 44] <-0
Transcript$Height[Transcript$Height > 79] <-0

HeightMedian<-aggregate(cbind(Height)~PatientGuid, data=Transcript[(is.na(Transcript$Weight) | Transcript$Weight!=0) & Transcript$Height!=0,], function(x) median(x))
names(HeightMedian) <- c('PatientGuid','HeightMedian')
Transcript<- merge(Transcript,HeightMedian,by="PatientGuid",all.x=TRUE)
Patient <- merge(Patient,HeightMedian,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

WeightMedian<-aggregate(cbind(Weight)~PatientGuid, data=Transcript[(is.na(Transcript$Height) | Transcript$Height!=0) & Transcript$Weight!=0,], function(x) median(x))
names(WeightMedian) <- c('PatientGuid','WeightMedian')
Transcript<- merge(Transcript,WeightMedian,by="PatientGuid",all.x=TRUE)
Patient <- merge(Patient,WeightMedian,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

#Transcript$Weight[Transcript$Weight < 0.8*Transcript$WeightMedian | Transcript$Weight > 1.2*Transcript$WeightMedian]<-0

Transcript$BMIc<-703*Transcript$Weight/(Transcript$HeightMedian^2)
Transcript$BMIc[is.na(Transcript$BMIc)]<-0

# Some functions for robust aggregate data.
#Calculating IQR
MaxTruncated <- function (x) { 
  ndata<-length(x)
  x<-sort(x)
  maxtrunc<-0
  if (ndata<=2) {maxtrunc<-x[ndata]}
  if ((ndata>=3) & (ndata<=8)){maxtrunc<-x[ndata-1]}
  if ((ndata>=9) & (ndata<=14)){maxtrunc<-x[ndata-2]}
  if ((ndata>=15) & (ndata<=23)){maxtrunc<-x[ndata-3]}
  if (ndata>=24){maxtrunc<-x[ndata-4]}
  return(maxtrunc)
}

MinTruncated <- function (x) { 
  ndata<-length(x)
  x<-sort(x)
  mintrunc<-0
  if (ndata<=2) {mintrunc<-x[1]}
  if ((ndata>=3) & (ndata<=8)){mintrunc<-x[2]}
  if ((ndata>=9) & (ndata<=14)){mintrunc<-x[3]}
  if ((ndata>=15) & (ndata<=23)){mintrunc<-x[4]}
  if (ndata>=24){mintrunc<-x[5]}
  return(mintrunc)
}

Rank2nd <- function (x) { 
  ndata<-length(x)
  x<-sort(x)
  mintrunc<-0
  if (ndata<=3) {mintrunc<-x[1]}
  if (ndata>=4) {mintrunc<-x[2]}
  return(mintrunc)
}

#REPLACE above with following

quart <- function(x) {
  x <- sort(x)
  n <- length(x)
  m <- (n+1)/2
  if (floor(m) != m) {
    l <- m-1/2; u <- m+1/2
  } else {
    l <- m-1; u <- m+1
  }
  c(Q1=x[median(1:l)], Q3=x[median(u:n)])
}


# Max truncated Weight
WeightMaxT<-aggregate(cbind(Weight)~PatientGuid, data=Transcript[Transcript$Weight>0 & !is.na(Transcript$Weight),], function(x) MaxTruncated(x))
names(WeightMaxT) <- c('PatientGuid','WeightMaxT')
Patient <- merge(Patient,WeightMaxT,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

# Max, Min truncated & Median BMI
BMIMaxT<-aggregate(cbind(BMIc)~PatientGuid, data=Transcript[Transcript$BMIc>0,], function(x) MaxTruncated(x))
names(BMIMaxT) <- c('PatientGuid','BMIMaxT')
Patient <- merge(Patient,BMIMaxT,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

BMIMinT<-aggregate(cbind(BMIc)~PatientGuid, data=Transcript[Transcript$BMIc>0,], function(x) MinTruncated(x))
names(BMIMinT) <- c('PatientGuid','BMIMinT')
Patient <- merge(Patient,BMIMinT,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 


BMIMedian<-aggregate(cbind(BMIc)~PatientGuid, data=Transcript[Transcript$BMIc>0,], function(x) median(x))
names(BMIMedian) <- c('PatientGuid','BMIMedian')
Patient <- merge(Patient,BMIMedian,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

# Range BMI
Patient$RangeBMI<-Patient$BMIMaxT-Patient$BMIMinT

# Clean Systolic & Diastolic BP
Transcript$SystolicBP<-as.numeric(Transcript$SystolicBP)
Transcript$SystolicBP[is.na(Transcript$SystolicBP)]<-0
Transcript$SystolicBP[Transcript$SystolicBP <= 20]<-10*Transcript$SystolicBP[Transcript$SystolicBP <= 20] # 0 typo
Transcript$SystolicBP[Transcript$SystolicBP <= 50]<-0
Transcript$DiastolicBP<-as.numeric(Transcript$DiastolicBP)
Transcript$DiastolicBP[is.na(Transcript$DiastolicBP)]<-0
Transcript$DiastolicBP[Transcript$DiastolicBP <= 9]<-10*Transcript$DiastolicBP[Transcript$DiastolicBP <= 9] # 0 typo
Transcript$DiastolicBP[Transcript$DiastolicBP <= 40]<-0
Transcript$DiastolicBP[Transcript$SystolicBP <= Transcript$DiastolicBP]<-0 # typo error
Transcript$DiastolicBP[Transcript$SystolicBP == 0]<-0 # only both valid
Transcript$SystolicBP[Transcript$DiastolicBP == 0]<-0 # only both valid


# Max y Min truncated, Median Systolic and Diastolic BP
SystolicBPMaxT<-aggregate(cbind(SystolicBP)~PatientGuid, data=Transcript[Transcript$SystolicBP>0,], function(x) MaxTruncated(x))
names(SystolicBPMaxT) <- c('PatientGuid','SystolicBPMaxT')
Patient <- merge(Patient,SystolicBPMaxT,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

SystolicBPMinT<-aggregate(cbind(SystolicBP)~PatientGuid, data=Transcript[Transcript$SystolicBP>0,], function(x) MinTruncated(x))
names(SystolicBPMinT) <- c('PatientGuid','SystolicBPMinT')
Patient <- merge(Patient,SystolicBPMinT,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

SystolicBPMedian<-aggregate(cbind(SystolicBP)~PatientGuid, data=Transcript[Transcript$SystolicBP>0,], function(x) median(x))
names(SystolicBPMedian) <- c('PatientGuid','SystolicBPMedian')
Patient <- merge(Patient,SystolicBPMedian,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

DiastolicBPMaxT<-aggregate(cbind(DiastolicBP)~PatientGuid, data=Transcript[Transcript$DiastolicBP>0,], function(x) MaxTruncated(x))
names(DiastolicBPMaxT) <- c('PatientGuid','DiastolicBPMaxT')
Patient <- merge(Patient,DiastolicBPMaxT,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

DiastolicBPMinT<-aggregate(cbind(DiastolicBP)~PatientGuid, data=Transcript[Transcript$DiastolicBP>0,], function(x) MinTruncated(x))
names(DiastolicBPMinT) <- c('PatientGuid','DiastolicBPMinT')
Patient <- merge(Patient,DiastolicBPMinT,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

DiastolicBPMedian<-aggregate(cbind(DiastolicBP)~PatientGuid, data=Transcript[Transcript$DiastolicBP>0,], function(x) median(x))
names(DiastolicBPMedian) <- c('PatientGuid','DiastolicBPMedian')
Patient <- merge(Patient,DiastolicBPMedian,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

# Range BP
Patient$RangeSystolicBP<-Patient$SystolicBPMaxT-Patient$SystolicBPMinT
Patient$RangeDiastolicBP<-Patient$DiastolicBPMaxT-Patient$DiastolicBPMinT
Patient$HighLowBP<-Patient$SystolicBPMedian-Patient$DiastolicBPMedian

# Max truncated, Median Respiratory Rate
Transcript$RespiratoryRate<-as.numeric(Transcript$RespiratoryRate)
Transcript$RespiratoryRate[is.na(Transcript$RespiratoryRate)]<-0
Transcript$RespiratoryRate[Transcript$RespiratoryRate <= 6]<-0 # typo error

RespiratoryRateMaxT<-aggregate(cbind(RespiratoryRate)~PatientGuid, data=Transcript[Transcript$RespiratoryRate>0,], function(x) MaxTruncated(x))
names(RespiratoryRateMaxT) <- c('PatientGuid','RespiratoryRateMaxT')
Patient <- merge(Patient,RespiratoryRateMaxT,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

RespiratoryRateMedian<-aggregate(cbind(RespiratoryRate)~PatientGuid, data=Transcript[Transcript$RespiratoryRate>0,], function(x) median(x))
names(RespiratoryRateMedian) <- c('PatientGuid','RespiratoryRateMedian')
Patient <- merge(Patient,RespiratoryRateMedian,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 


# Rank2nd (second lowest) & Median Temperature
Transcript$Temperature<-as.numeric(Transcript$Temperature)
Transcript$Temperature[is.na(Transcript$Temperature)]<-0
Transcript$Temperature[Transcript$Temperature <= 75]<-0 # typo error

TemperatureRank2nd<-aggregate(cbind(Temperature)~PatientGuid, data=Transcript[Transcript$Temperature>0,], function(x) Rank2nd(x))
names(TemperatureRank2nd) <- c('PatientGuid','TemperatureRank2nd')
Patient <- merge(Patient,TemperatureRank2nd,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

TemperatureMedian<-aggregate(cbind(Temperature)~PatientGuid, data=Transcript[Transcript$Temperature>0,], function(x) median(x))
names(TemperatureMedian) <- c('PatientGuid','TemperatureMedian')
Patient <- merge(Patient,TemperatureMedian,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 


# Transcript by Specialty
InternalMedicine<-aggregate(cbind(PhysicianSpecialty)~PatientGuid, data=Transcript[Transcript$PhysicianSpecialty=='Internal Medicine',], function(x) length(x))
names(InternalMedicine) <- c('PatientGuid','InternalMedicine')
Patient <- merge(Patient,InternalMedicine,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

CardiovascularDisease<-aggregate(cbind(PhysicianSpecialty)~PatientGuid, data=Transcript[Transcript$PhysicianSpecialty=='Cardiovascular Disease',], function(x) length(x))
names(CardiovascularDisease) <- c('PatientGuid','CardiovascularDisease')
Patient <- merge(Patient,CardiovascularDisease,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

FamilyPractice<-aggregate(cbind(PhysicianSpecialty)~PatientGuid, data=Transcript[Transcript$PhysicianSpecialty=='Family Practice',], function(x) length(x))
names(FamilyPractice) <- c('PatientGuid','FamilyPractice')
Patient <- merge(Patient,FamilyPractice,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

GeneralPractice<-aggregate(cbind(PhysicianSpecialty)~PatientGuid, data=Transcript[Transcript$PhysicianSpecialty=='General Practice',], function(x) length(x))
names(GeneralPractice) <- c('PatientGuid','GeneralPractice')
Patient <- merge(Patient,GeneralPractice,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

Podiatry<-aggregate(cbind(PhysicianSpecialty)~PatientGuid, data=Transcript[Transcript$PhysicianSpecialty=='Podiatry',], function(x) length(x))
names(Podiatry) <- c('PatientGuid','Podiatry')
Patient <- merge(Patient,Podiatry,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

# Unique specialties other than Pediatrics , FamilyPractice
NumSpecialties<-aggregate(cbind(PhysicianSpecialty)~PatientGuid, data=Transcript[!(Transcript$PhysicianSpecialty %in% c('Pediatrics','Family Practice')),], function(x) length(unique(x)))
names(NumSpecialties) <- c('PatientGuid','NumSpecialties')
Patient <- merge(Patient,NumSpecialties,by="PatientGuid",all.x=TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 


Patient$Age = 2016 - Patient$YearOfBirth

Patient$TotalVisits = Patient$InternalMedicine + Patient$CardiovascularDisease + Patient$FamilyPractice + Patient$GeneralPractice + Patient$Podiatry + Patient$NumSpecialties

rm("Transcript")

rm("HeightMedian", "WeightMedian", "WeightMaxT", "BMIMaxT", "BMIMinT", "BMIMedian", "SystolicBPMaxT", "SystolicBPMinT" )

rm("SystolicBPMedian" , "DiastolicBPMaxT", "DiastolicBPMinT", "DiastolicBPMedian", "RespiratoryRateMaxT", "RespiratoryRateMedian", "TemperatureRank2nd", "TemperatureMedian")

rm("InternalMedicine" , "CardiovascularDisease", "FamilyPractice", "GeneralPractice", "Podiatry", "NumSpecialties")
rm("MaxTruncated", "MinTruncated", "quart", "Rank2nd")

#Lab
setwd("/home/srishti/workspace")
LabTable <- read.csv("modifiedLab.csv", header = TRUE)

#create new list
i <- 1
labList <- c()
while(i <= 3470){
  if(!(LabTable$PanelName[i] %in% labList))
    labList[length(labList)+1] <- as.character(LabTable$PanelName[i])
  i <- i+1
}


#create new fields
i <- 1
j <- 22
while(i <= 87){
  LabTable$labList <- ifelse(LabTable$PanelName == labList[i], 1, 0);
  colnames(LabTable)[j] <- labList[i]
  i=i+1;
  j=j+1;
}
LabTable$Status <- as.character(LabTable$Status)
LabTable$Status <- ifelse(LabTable$Status == "Final", 1, 0)

LabTable$ResultStatus <- as.character(LabTable$ResultStatus)
LabTable$ResultStatus<- ifelse(LabTable$ResultStatus == "Final", 1, 0)


rm("labList")

#create new list
i <- 1
labList <- c()
while(i <= 3470){
  if(!(LabTable$ObservationValue[i] %in% labList))
    labList[length(labList)+1] <- as.character(LabTable$ObservationValue[i])
  i <- i+1
}


#create new fields
i <- 1
j <- 109
while(i <= 810){
  LabTable$labList <- ifelse(LabTable$ObservationValue == labList[i], 1, 0);
  colnames(LabTable)[j] <- labList[i]
  i=i+1;
  j=j+1;
}

LabTable$ObservationValue <- NULL
LabTable$LabResultGuid <- NULL
LabTable$LabPanelGuid <- NULL
LabTable$PanelName <- NULL
LabTable$LabObservationGuid <- NULL 
LabTable$TranscriptGuid <- NULL
LabTable$FacilityGuid <- NULL
LabTable$AncestorLabResultGuid <- NULL
LabTable$PracticeGuid <- NULL
LabTable$ReportYear <- NULL
LabTable$HL7Text <- NULL
LabTable$HL7Identifier <- NULL
LabTable$HL7CodingSystem <- NULL
LabTable$AbnormalFlags <- NULL
LabTable$IsAbnormalValue <- NULL
LabTable$Units <- NULL
LabTable$ReferenceRange <- NULL
LabTable$Column <- NULL

Patient <- merge(Patient, LabTable, by = 'PatientGuid', all.x = TRUE)


rm("LabTable", "labList")
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 
Patient[is.na(Patient)] <- 0
Patient <- Patient[!duplicated(Patient), ]





# Allergen
trainingAllergy<-dbGetQuery(con, "SELECT * FROM training_allergy")
testAllergy<-dbGetQuery(con, "SELECT * FROM test_allergy")
names(trainingAllergy)[names(trainingAllergy)=="MedicationNdcCode"]<-"MedicationNDCCode"
Allergy<-rbind(trainingAllergy,testAllergy)
rm("trainingAllergy","testAllergy")


Allergy$SeverityName[Allergy$SeverityName=="Very Mild"] <- 1
Allergy$SeverityName[Allergy$SeverityName=="Mild"] <- 2
Allergy$SeverityName[Allergy$SeverityName=="Modest"] <- 3
Allergy$SeverityName[Allergy$SeverityName=="Severe"] <- 4

i=1

allergyList = c()
while(i<4217){
  if(!(Allergy$AllergyType[i] %in% allergyList))
    allergyList[length(allergyList)+1]=Allergy$AllergyType[i];
  i=i+1
}

i=1
reactionList <- c()
while(i<4217){
  if(!(Allergy$ReactionName[i] %in% reactionList))
    reactionList[length(reactionList )+1]=Allergy$ReactionName[i];
  i=i+1
}

i=1
j=10
while(i<19){
  Allergy$allergyList <- ifelse(Allergy$AllergyType == allergyList[i], 1, 0);
  Allergy$allergyList <- Allergy$allergyList * as.numeric(Allergy$SeverityName);
  colnames(Allergy)[j] <- allergyList[i]
  i=i+1;
  j=j+1;
}
i=1
j=28
while(i<26){
  Allergy$reactionList <- ifelse(Allergy$ReactionName == reactionList[i], 1, 0);
  Allergy$reactionList <- Allergy$reactionList * as.numeric(Allergy$SeverityName);
  colnames(Allergy)[j] <- reactionList[i];
  i=i+1;
  j=j+1;
}

rm("reactionList","allergyList")


Allergy$AllergyGuid <- NULL
Allergy$AllergyType <- NULL
Allergy$StartYear <- NULL
Allergy$ReactionName <- NULL
Allergy$SeverityName <- NULL
Allergy$MedicationNDCCode <- NULL
Allergy$Medication <- NULL
Allergy$UserGuid <- NULL
Allergy$MedicationName <- NULL



Patient <- merge(Patient, Allergy, by = 'PatientGuid', all.x = TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 
Patient[is.na(Patient)] <- 0

Patient <- Patient[!duplicated(Patient), ]

rm("Allergy")

#Smoke codes
SmokeCode<-dbGetQuery(con, "SELECT * FROM smokingStatus")



#Smoking
trainingSmoking<-dbGetQuery(con, "SELECT * FROM training_patientSmokingStatus")
testSmoking<-dbGetQuery(con, "SELECT * FROM test_patientSmokingStatus")

SmokingStatus<-rbind(trainingSmoking, testSmoking)
rm("trainingSmoking","testSmoking")

#create list
i=1
smokeList = c()
while(i<=7383){
  if(!(SmokingStatus$SmokingStatusGuid[i] %in% smokeList))
    smokeList[length(smokeList)+1]=SmokingStatus$SmokingStatusGuid[i]
  i=i+1
}


#create new fields
i=1
j=5
while(i<=10){
  SmokingStatus$smokeList <- ifelse(SmokingStatus$SmokingStatusGuid == smokeList[i], 1, 0);
  #smokingStatus$smokeList <- Allergy$allergyList * as.numeric(Allergy$SeverityName);
  colnames(SmokingStatus)[j] <- smokeList[i]
  i=i+1;
  j=j+1;
}

#rename fields
j <- 5
i <- 1
k <- 0
while(j<=15){
  if(colnames(SmokingStatus)[j] %in% SmokeCode$SmokingStatusGuid) {
    k=which(SmokeCode$SmokingStatusGuid %in% colnames(SmokingStatus)[j])
    colnames(SmokingStatus)[j] <- SmokeCode$Description[k]
  }
  j <- j + 1;
}

#add new field for NIST
i <- 1
k <- 1
while(i<7384){
  
  k=which(SmokeCode$SmokingStatusGuid %in% SmokingStatus$SmokingStatusGuid[i])
  SmokingStatus$NISTCode[i] <- SmokeCode$NISTcode[k]
  
  i <- i + 1;
  
}
SmokingStatus$PatientSmokingStatusGuid <- NULL
SmokingStatus$SmokingStatusGuid <- NULL
SmokingStatus$EffectiveYear <- NULL

rm("smokeList", "SmokeCode")
Patient <- merge(Patient, SmokingStatus, by='PatientGuid', all.x = TRUE)

Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

rm("SmokingStatus")
Patient[is.na(Patient)] <- 0
Patient <- Patient[!duplicated(Patient), ]



#Condition
Condition <-dbGetQuery(con, "SELECT * FROM condition")
training_patientCondition<-dbGetQuery(con, "SELECT * FROM training_patientCondition")
test_patientCondition<-dbGetQuery(con, "SELECT * FROM test_patientCondition")

PatientCondition<-rbind(training_patientCondition, test_patientCondition)
rm("training_patientCondition","test_patientCondition")


#create new field
i=1
condList = c()
while(i<=4268){
  if(!(PatientCondition$ConditionGuid[i] %in% condList))
    condList[length(condList)+1]=PatientCondition$ConditionGuid[i]
  i=i+1
}

#create new fields
i=1
j=5
while(i<3){
  PatientCondition$condList <- ifelse(PatientCondition$ConditionGuid == condList[i], 1, 0);
  #smokingStatus$smokeList <- Allergy$allergyList * as.numeric(Allergy$SeverityName);
  colnames(PatientCondition)[j] <- condList[i]
  i=i+1;
  j=j+1;
}

#rename new fields
j <- 5
i <- 1
k <- 0
while(j<=7){
  if(colnames(PatientCondition)[j] %in% Condition$ConditionGuid) {
    k=which(Condition$ConditionGuid %in% colnames(PatientCondition)[j])
    colnames(PatientCondition)[j] <- Condition$Name[k]
  }
  j <- j + 1;
}
PatientCondition$PatientConditionGuid <- NULL
PatientCondition$ConditionGuid <- NULL
PatientCondition$CreatedYear <- NULL

Patient <- merge(Patient, PatientCondition, by='PatientGuid', all.x = TRUE)

Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 
rm("PatientCondition","condList","Condition")

Patient <- Patient[!duplicated(Patient), ]



#Prescription
training_prescription<-dbGetQuery(con, "SELECT * FROM training_prescription")
test_prescription<-dbGetQuery(con, "SELECT * FROM test_prescription")

Prescription<-rbind(training_prescription, test_prescription)
rm("training_prescription","test_prescription")

NewPrescription <- data.frame(PatientGuid= character(), TotalCount=list())

TotalRefillsNeeded<-aggregate(cbind(RefillAsNeeded)~PatientGuid, data=Prescription, function(x) sum(x))
names(TotalRefillsNeeded) <- c('PatientGuid','TotalRefillsNeeded')
NewPrescription <- TotalRefillsNeeded

MeanRefillsNeeded<-aggregate(cbind(RefillAsNeeded)~PatientGuid, data=Prescription, function(x) mean(x))
names(MeanRefillsNeeded) <- c('PatientGuid','MeanRefillsNeeded')
NewPrescription <- merge(NewPrescription,MeanRefillsNeeded,by="PatientGuid",all.x=TRUE)

Prescription$NumberOfRefills[is.na(Prescription$NumberOfRefills)] <- 0
Prescription$NumberOfRefills <- as.numeric(Prescription$NumberOfRefills)

TotalNumberOfRefills <- aggregate(cbind(NumberOfRefills)~PatientGuid, data=Prescription, function(x) sum(x))
names(TotalNumberOfRefills) <- c('PatientGuid','TotalNumberOfRefills')
NewPrescription <- merge(NewPrescription,TotalNumberOfRefills,by="PatientGuid",all.x=TRUE)

MeanNumberOfRefills <- aggregate(cbind(NumberOfRefills)~PatientGuid, data=Prescription, function(x) mean(x))
names(MeanNumberOfRefills) <- c('PatientGuid','MeanNumberOfRefills')
NewPrescription <- merge(NewPrescription,MeanNumberOfRefills,by="PatientGuid",all.x=TRUE)


GenericCount <- aggregate(cbind(GenericAllowed)~PatientGuid, data=Prescription, function(x) sum(x))
names(GenericCount) <- c('PatientGuid','GenericCount')
NewPrescription <- merge(NewPrescription,GenericCount,by="PatientGuid",all.x=TRUE)


TotalPrescriptions <- aggregate(PrescriptionGuid~PatientGuid, data=Prescription, function(x) length(x))
names(TotalPrescriptions) <- c('PatientGuid','TotalPrescriptions')
NewPrescription <- merge(NewPrescription,TotalPrescriptions,by="PatientGuid",all.x=TRUE)


ByPrescriptionYear <- aggregate(PrescriptionGuid~PatientGuid + PrescriptionYear,  data=Prescription, function(x) length(x))
names(ByPrescriptionYear) <- c('PatientGuid','PrescriptionYear','ByPrescriptionYear')

MeanPrescriptions <- aggregate(cbind(ByPrescriptionYear)~PatientGuid, data=ByPrescriptionYear, function(x) mean(x))
names(MeanPrescriptions) <- c('PatientGuid','MeanPrescriptions')
NewPrescription <- merge(NewPrescription,MeanPrescriptions,by="PatientGuid",all.x=TRUE)

NewPrescription$RefillsByPrescription <- with(NewPrescription, TotalRefillsNeeded/TotalPrescriptions)

NewPrescription$GenericByPrescription <- with(NewPrescription, GenericCount/TotalPrescriptions)
rm("Prescription")
rm("TotalRefillsNeeded" , "MeanRefillsNeeded", "TotalNumberOfRefills", "MeanNumberOfRefills", "GenericCount", "TotalPrescriptions", "ByPrescriptionYear", "MeanPrescriptions")
Patient <- merge(Patient,NewPrescription,by="PatientGuid",all.x=TRUE)
rm("NewPrescription")
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 

Patient <- Patient[!duplicated(Patient), ]


#Medication
training_medication<-dbGetQuery(con, "SELECT * FROM training_medication")
test_medication<-dbGetQuery(con, "SELECT * FROM test_medication")

Medication <- rbind(training_medication, test_medication)
rm("training_medication", "test_medication")

setwd("/home/srishti/workspace/csv files")



temp = list.files(pattern="*.csv")
for (i in 1:length(temp)) assign(temp[i], read.csv(temp[i]))

setNames(temp,gsub(".csv",'',temp))
list2env(
  lapply(setNames(temp, make.names(gsub("*csv$", "", temp))), 
         read.csv), envir = .GlobalEnv)



Medication$Schizophrenia <- ifelse(Medication$MedicationNdcCode %in% SAA.A.$ndc_code, 1, 0)

Medication$PersistentMedications <- ifelse(Medication$MedicationNdcCode %in% MPM.B.$ndc_code || Medication$MedicationNdcCode %in% MPM.C.$ndc_code || Medication$MedicationNdcCode %in% MPM.D.$ndc_code, 1, 0)

Medication$AntibioticUtilization <- ifelse(Medication$MedicationNdcCode %in% ABX.A.$ndc_code || Medication$MedicationNdcCode %in% ABX.B.$ndc_code || Medication$MedicationNdcCode %in% ABX.C.$ndc_code, 1, 0)

Medication$Antidepressants <- ifelse(Medication$MedicationNdcCode %in% AMM.C.$ndc_code, 1, 0)

Medication$Pharyngitis <- ifelse(Medication$MedicationNdcCode %in% CWP.C.$ndc_code, 1, 0)

Medication$Asthama <- ifelse(Medication$MedicationNdcCode %in% AMR.A.$ndc_code, 1, 0)

Medication$AcuteBronchitis <- ifelse(Medication$MedicationNdcCode %in% AAB.D.$ndc_code, 1, 0)

Medication$Chlamydia <- ifelse(Medication$MedicationNdcCode %in% CHL.A.$ndc_code || Medication$MedicationNdcCode %in% CHL.E.$ndc_code,  1, 0)

Medication$Diabetes <- ifelse(Medication$MedicationNdcCode %in% CDC.A.$ndc_code || Medication$MedicationNdcCode %in% CDC.L.$ndc_code,  1, 0)

Medication$IschemicVascularDiseaseCare <- ifelse(Medication$MedicationNdcCode %in% IVD.E.$ndc_code, 1, 0)

Medication$IschemicVascularDiseaseMgmt <- ifelse(Medication$MedicationNdcCode %in% DIVD.G.$ndc_code, 1, 0)

Medication$AntipsychoticMedications <- ifelse(Medication$MedicationNdcCode %in% SSD.D.$ndc_code, 1, 0)

Medication$AntiRheumatic <- ifelse(Medication$MedicationNdcCode %in% ART.C.$ndc_code, 1, 0)

Medication$ADHDMedication <- ifelse(Medication$MedicationNdcCode %in% ADD.A.$ndc_code, 1, 0)

Medication$Osteoporosis <- ifelse(Medication$MedicationNdcCode %in% OMW.C.$ndc_code, 1, 0)

Medication$BetaBlockerTreatmentAfterHeartAttack <- ifelse(Medication$MedicationNdcCode %in% PBH.B.$ndc_code || Medication$MedicationNdcCode %in% PBH.D.$ndc_code, 1, 0)

Medication$COPDExacerbation <- ifelse(Medication$MedicationNdcCode %in% PCE.C.$ndc_code || Medication$MedicationNdcCode %in% PCE.D.$ndc_code, 1, 0)

Medication$HarmfulDrugDiseaseInteractions <- ifelse(Medication$MedicationNdcCode %in% DDE.A.$ndc_code || Medication$MedicationNdcCode %in% DDE.B.$ndc_code || Medication$MedicationNdcCode %in% DDE.C.$ndc_code || Medication$MedicationNdcCode %in% DDE.D.$ndc_code || Medication$MedicationNdcCode %in% DDE.E.$ndc_code, 1, 0)

Medication$AsthamaMedication <- ifelse(Medication$MedicationNdcCode %in% ASM.C.$ndc_code || Medication$MedicationNdcCode %in% ASM.D.$ndc_code,  1, 0)

Medication$HighRiskMedications <- ifelse(Medication$MedicationNdcCode %in% DAE.A.$ndc_code || Medication$MedicationNdcCode %in% DAE.B.$ndc_code || Medication$MedicationNdcCode %in% DAE.C.$ndc_code,  1, 0)




temp1 <- substr(temp, 1, which(strsplit(temp, '')[[1]]=='.')-1)
rm(list=temp)
rm("temp", "temp1")
rm("AAB.D.","ABX.A.","ABX.B.","ABX.C.","ADD.A.","AMM.C.","AMR.A.","ART.C.","ASM.C.","PCE.C.","ASM.D.","CDC.A.","CDC.L.","CHL.A.","CHL.E.","CWP.C.","DAE.A.","DAE.B.","DAE.C.","DDE.A.","DDE.B.","DDE.C.","DDE.D.", "DDE.E.", "DIVD.G.", "IVD.E.", "MPM.B.", "MPM.C.", "MPM.D.", "OMW.C.", "PBH.B.", "PBH.D.", "PCE.D.", "SAA.A.", "SSD.D.")


Medication$MedicationGuid <- NULL
Medication$MedicationNdcCode <-NULL
Medication$MedicationName <- NULL
Medication$MedicationStrength <- NULL
Medication$Schedule <- NULL
Medication$DiagnosisGuid <- NULL
Medication$UserGuid <- NULL



Patient <- merge(Patient, Medication, by='PatientGuid', all.x = TRUE)
rm("Medication")
gc()
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 
Patient[is.na(Patient)] <- 0


Patient <- Patient[!duplicated(Patient), ]




#Diagnosis
training_diagnosis <- dbGetQuery(con, "SELECT * FROM training_diagnosis")
test_diagnosis <- dbGetQuery(con, "SELECT * FROM test_diagnosis")

Diagnosis <- rbind(training_diagnosis,test_diagnosis) 
rm("training_diagnosis", "test_diagnosis")

# Diagnosis$ICD9Code <- substr(Diagnosis$ICD9Code, 1, which(strsplit(Diagnosis$ICD9Code, '')[[1]]=='.')-1)

Diagnosis$StopYear[Diagnosis$StopYear == "NULL"]<- 0
Diagnosis$StopYear = as.numeric(Diagnosis$StopYear)

Diagnosis$Duration <-  Diagnosis$StopYear - Diagnosis$StartYear + 1

Diagnosis$Duration[Diagnosis$Duration > 1000] <- 0
Diagnosis$Duration[Diagnosis$Duration < -1000] <- 0

setwd("/home/srishti/workspace")
Diagnosis$ICD9Code <- substr(Diagnosis$ICD9Code, 1, which(strsplit(Diagnosis$ICD9Code, '')[[1]]=='.')-1)
ICD9 = read.csv("icd9.csv", header = TRUE)
Diagnosis$DiagnosisGuid <- NULL
#classify

Diagnosis$ICD9Code[(substr(Diagnosis$ICD9Code, 1, 1) == "V") | (substr(Diagnosis$ICD9Code, 1, 1) == "E") | (substr(Diagnosis$ICD9Code, 1, 1) == "e") | (substr(Diagnosis$ICD9Code, 1, 1) == "v") ] <- -1

Diagnosis$ICD9Code <- as.numeric(Diagnosis$ICD9Code)

i <- 1
k <- -1

while(i <= 142741){
  if(Diagnosis$ICD9Code[i] != -1){
    k <- which((as.numeric(Diagnosis$ICD9Code[i]) > ICD9$upper) == FALSE)[1]
    Diagnosis$ICD9Code[i] <- as.character(ICD9$category[k])
  }
  i <- i + 1
}

Diagnosis$ICD9Code[Diagnosis$ICD9Code == -1] <- "External causes of injury and supplemental classification"



#create new list
i <- 1
diagList <- c()
while(i <= 70){
  if(!(ICD9$category[i] %in% diagList))
    diagList[length(diagList)+1] <- as.character(ICD9$category[i])
  i <- i+1
}
diagList[length(diagList) + 1] <- "External causes of injury and supplemental classification"

#create new fields
i <- 1
j <- 9
while(i <= 71){
  current <- ifelse(Diagnosis$Duration == 0, 1, 2)
  acute <- ifelse(Diagnosis$Acute == 1, 2, 1)
  Diagnosis$diagList <- ifelse(Diagnosis$ICD9Code == diagList[i], 1, 0);
  colnames(Diagnosis)[j] <- diagList[i]
  i=i+1;
  j=j+1;
}
rm("current","acute")
rm("diagList")
rm("ICD9")

Diagnosis$ICD9Code <- NULL
Diagnosis$DiagnosisDescription <- NULL
Diagnosis$StartYear <- NULL
Diagnosis$StopYear <- NULL
Diagnosis$Acute <- NULL
Diagnosis$UserGuid <- NULL

Diagnosis <- Diagnosis[!duplicated(Diagnosis), ]

Patient <- merge(Patient, Diagnosis, by = 'PatientGuid', all.x = TRUE)
Patient[is.na(Patient[,ncol(Patient)]),ncol(Patient)]<-0 
Patient[is.na(Patient)] <- 0
rm("Diagnosis")


Patient$UserGuid <- NULL
Patient$MedicationGuid <- NULL 
Patient$MedicationName <- NULL
Patient$MedicationNdcCode <- NULL

Patient$HL7Text <- NULL
Patient$HL7Identifier <- NULL
Patient$HL7CodingSystem <- NULL
Patient$AbnormalFlags <- NULL


#create new state list
i <- 1
stateList <- c()
while(i <= 148781){
  if(!(Patient$State[i] %in% stateList))
    stateList[length(stateList)+1] <- as.character(Patient$State[i])
  i <- i+1
}

#create new year list
i <- 1
yearList <- c()
while(i <= 148781){
  if(!(Patient$YearOfBirth[i] %in% yearList))
    yearList[length(yearList)+1] <- as.character(Patient$YearOfBirth[i])
  i <- i+1
}


i <- 1
j <- 282
while(i <= 52){
  Patient$stateList <- ifelse(Patient$State == stateList[i], 1, 0);
  colnames(Patient)[j] <- stateList[i]
  i=i+1;
  j=j+1;
}

i <- 1
j <- 333
while(i <= 73){
  Patient$yearList <- ifelse(Patient$YearOfBirth == yearList[i], 1, 0);
  colnames(Patient)[j] <- yearList[i]
  i=i+1;
  j=j+1;
}

Patient$Male <-  ifelse(Patient$Gender == 'M', 1, 0)
Patient$Female <-  ifelse(Patient$Gender == 'F', 1, 0)
Patient$Gender <- NULL
Patient$State <- NULL
Patient$YearOfBirth <- NULL

write.csv(Patient,"SingleFeaturesTable.csv")



