package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	_ "modernc.org/sqlite"
	"net/http"
	"os"
	"strconv"
	"time"
)

type Image struct {
	FileName    string
	Description string
	UploadTime  string
}

type Database struct {
	DB *sql.DB
}

var DBPath string
var ImageTable string

func (d *Database) addImageToDatabase(i *Image) error {
	log.Printf("Added image: %+v to database\n", *i)
	statement := fmt.Sprintf("INSERT into %s VALUES(?,?,?);", ImageTable)
	_, err := d.DB.Exec(statement, i.FileName, i.Description, i.UploadTime)
	if err != nil {
		return err
	}
	return nil
}

func (d *Database) getImagesFromDatabase() ([]Image, error) {
	var images []Image
	rows, err := d.DB.Query("SELECT * from images;")
	if err != nil {
		return nil, err
	}

	for rows.Next() {
		var i Image
		err = rows.Scan(&i.FileName, &i.Description, &i.UploadTime)
		if err != nil {
			return nil, err
		}
		images = append(images, i)
	}
	rows.Close()

	return images, nil
}

func createImage(req *http.Request) (Image, error) {
	var i Image

	err := json.NewDecoder(req.Body).Decode(&i)

	if err != nil {
		return i, err
	}

	return i, nil
}

func (d *Database) imageHandler(w http.ResponseWriter, req *http.Request) {
	switch req.Method {
	case "GET":
		images, err := d.getImagesFromDatabase()
		if err != nil {
			fmt.Println("Error getting images from database")
		}
		j, err := json.Marshal(images)

		fmt.Fprintf(w, string(j))
	case "POST":
		image, err := createImage(req)
		if err != nil {
			fmt.Fprintf(w, "Error parsing request body: %+v", err)
		}
		image.UploadTime = time.Now().UTC().Format("2006-01-02T15:04:05-0700")
		err = d.addImageToDatabase(&image)
		if err != nil {
			log.Fatalf("Error adding image metadata to database: %s", err.Error())
		}
	default:
		fmt.Fprintln(w, "Only GET and POST methods supported")
	}
}

func connectDatabase() (*Database, error) {
	db, err := sql.Open("sqlite", DBPath)
	if err != nil {
		return nil, err
	}
	return &Database{
		DB: db,
	}, nil
}

func main() {
	ServerPort, err := strconv.Atoi(os.Getenv("SERVER_PORT"))
	if err != nil {
		log.Fatal("Port is incorrect")
	}

	DBPath = os.Getenv("DATABASE_FILE_PATH")
	ImageTable = os.Getenv("IMAGE_TABLE_NAME")

	database, err := connectDatabase()

	if err != nil {
		log.Fatalf("Error opening database: %s", err.Error())
	}

	defer database.DB.Close()

	// Path handlers
	http.HandleFunc("/images", database.imageHandler)

	fmt.Printf("Server launching on port: %d\n", ServerPort)

	http.ListenAndServe(fmt.Sprintf(":%d", ServerPort), nil)
}
