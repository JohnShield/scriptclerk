echo This shows whether you have applied a patch. 

echo Try turning on a patch for this application in the settings
if [ -f exampleC.cpp ]; then
    echo You have applied the patch for this program.
    echo ############################
    cat exampleC.cpp
    echo ############################
else
    echo You have not applied the patch for this program.
fi

sleep 40
