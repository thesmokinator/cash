#!/bin/bash
# Script per compilare e firmare localmente l'app Cash

set -e

echo "=== Cash Local Build Script ==="
echo ""

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variabili
BUILD_DIR="build"
APP_NAME="Cash"
BUNDLE_ID="com.thesmokinator.Cash"
TEAM_ID="932KJJ3UZK"

# Cerca il certificato
echo -e "${BLUE}1. Cercando certificato Developer ID...${NC}"
DEVELOPER_ID=$(security find-certificate -c "Developer ID Application" | grep alis | sed -n '1p' | sed 's/.*alis="\([^"]*\)".*/\1/')

if [ -z "$DEVELOPER_ID" ]; then
    echo -e "${RED}Errore: Certificato Developer ID non trovato${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Trovato: $DEVELOPER_ID${NC}"
echo ""

# Clean
echo -e "${BLUE}2. Pulizia build precedenti...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
echo -e "${GREEN}✓ Fatto${NC}"
echo ""

# Archive
echo -e "${BLUE}3. Creazione archivio...${NC}"
xcodebuild \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive

echo -e "${GREEN}✓ Archivio creato${NC}"
echo ""

# Export
echo -e "${BLUE}4. Export dell'app...${NC}"
mkdir -p "$BUILD_DIR/export"

xcodebuild \
    -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath "$BUILD_DIR/export"

echo -e "${GREEN}✓ App esportata${NC}"
echo ""

# Code Sign
echo -e "${BLUE}5. Firma del codice (Code Signing)...${NC}"
codesign -v --deep --strict --options runtime \
    -s "$DEVELOPER_ID" \
    "$BUILD_DIR/export/$APP_NAME.app"

echo -e "${GREEN}✓ App firmata${NC}"
echo ""

# Create DMG
echo -e "${BLUE}6. Creazione DMG...${NC}"
mkdir -p "$BUILD_DIR/dmg"
cp -r "$BUILD_DIR/export/$APP_NAME.app" "$BUILD_DIR/dmg/"

# Crea il DMG con layout personalizzato
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$BUILD_DIR/dmg" \
    -ov -format UDZO \
    "$BUILD_DIR/$APP_NAME.dmg"

echo -e "${GREEN}✓ DMG creato: $BUILD_DIR/$APP_NAME.dmg${NC}"
echo ""

# Notarization (opzionale)
read -p "Desideri notarizzare il DMG? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${BLUE}7. Notarizzazione...${NC}"
    read -p "Inserisci il tuo Apple ID: " apple_id
    
    echo "Sottomissione per notarizzazione..."
    NOTARIZE_UUID=$(xcrun notarytool submit "$BUILD_DIR/$APP_NAME.dmg" \
        --apple-id "$apple_id" \
        --password \
        --team-id "$TEAM_ID" \
        --wait \
        --output-format json | jq -r '.id')
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Notarizzazione completata (ID: $NOTARIZE_UUID)${NC}"
        
        echo "Applicazione stapling..."
        xcrun stapler staple "$BUILD_DIR/$APP_NAME.dmg"
        echo -e "${GREEN}✓ DMG notarizzato e stapled${NC}"
    else
        echo -e "${RED}Notarizzazione fallita${NC}"
    fi
else
    echo -e "${BLUE}Notarizzazione saltata${NC}"
fi

echo ""
echo -e "${GREEN}=== Build completato ===${NC}"
echo ""
echo "Output: $BUILD_DIR/$APP_NAME.dmg"
echo ""
echo "Prossimi passaggi:"
echo "1. Testare l'app: hdiutil attach $BUILD_DIR/$APP_NAME.dmg"
echo "2. Verificare la firma: codesign -v --verbose=4 /Volumes/$APP_NAME/$APP_NAME.app"
echo "3. Caricare su GitHub Releases oppure distribuire"
