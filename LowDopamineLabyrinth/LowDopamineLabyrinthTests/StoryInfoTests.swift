import XCTest
@testable import LowDopamineLabyrinth

final class StoryInfoTests: XCTestCase {

    func testStoryInfoCreation() {
        let story = StoryInfo(
            number: 1,
            title: "Denny Finds Mommy Coral",
            location: "sandy_shore",
            characterEnd: "coral",
            isFree: true,
            isAdventure: false,
            labyrinthIds: ["denny_001_easy", "denny_001_medium", "denny_001_hard"]
        )

        XCTAssertEqual(story.id, 1)
        XCTAssertEqual(story.number, 1)
        XCTAssertEqual(story.title, "Denny Finds Mommy Coral")
        XCTAssertEqual(story.location, "sandy_shore")
        XCTAssertEqual(story.characterEnd, "coral")
        XCTAssertTrue(story.isFree)
        XCTAssertFalse(story.isAdventure)
        XCTAssertEqual(story.labyrinthIds.count, 3)
    }

    func testStoryInfoFreeStatus() {
        for storyNum in 1...3 {
            let story = StoryInfo(
                number: storyNum,
                title: "Story \(storyNum)",
                location: "loc",
                characterEnd: "char",
                isFree: storyNum <= 3,
                isAdventure: false,
                labyrinthIds: []
            )
            XCTAssertTrue(story.isFree, "Story \(storyNum) should be free")
        }

        let story4 = StoryInfo(
            number: 4,
            title: "Story 4",
            location: "loc",
            characterEnd: "char",
            isFree: false,
            isAdventure: false,
            labyrinthIds: []
        )
        XCTAssertFalse(story4.isFree, "Story 4 should not be free")
    }

    func testStoryInfoAdventureStatus() {
        for storyNum in 1...10 {
            let story = StoryInfo(
                number: storyNum,
                title: "Story \(storyNum)",
                location: "loc",
                characterEnd: "char",
                isFree: false,
                isAdventure: storyNum >= 11,
                labyrinthIds: []
            )
            XCTAssertFalse(story.isAdventure, "Story \(storyNum) should not be adventure")
        }

        for storyNum in 11...20 {
            let story = StoryInfo(
                number: storyNum,
                title: "Story \(storyNum)",
                location: "loc",
                characterEnd: "char",
                isFree: false,
                isAdventure: storyNum >= 11,
                labyrinthIds: []
            )
            XCTAssertTrue(story.isAdventure, "Story \(storyNum) should be adventure")
        }
    }
}

final class LabyrinthModelTests: XCTestCase {

    private func makeLabyrinth(id: String) -> Labyrinth {
        Labyrinth(
            id: id,
            ageRange: nil,
            difficulty: "easy",
            theme: "ocean",
            title: "Test",
            storySetup: "Story",
            instruction: "Go",
            ttsInstruction: "Go",
            characterStart: LabyrinthCharacter(type: "crab", description: "Denny", position: "bottom_left", name: "Denny", imageAsset: "denny"),
            characterEnd: LabyrinthCharacter(type: "fish", description: "Finn", position: "top_right", name: "Finn", imageAsset: "finn"),
            educationalQuestion: "Q?",
            funFact: "Fact",
            completionMessage: "Done!",
            pathData: PathData(
                svgPath: "M0,0 L100,100",
                solutionPath: "M0,0 L100,100",
                width: 30,
                complexity: "easy",
                mazeType: "grid",
                startPoint: PointData(x: 0, y: 0),
                endPoint: PointData(x: 100, y: 100),
                segments: [SegmentData(start: PointData(x: 0, y: 0), end: PointData(x: 100, y: 100))],
                canvasWidth: 600,
                canvasHeight: 500,
                controlPoints: nil,
                items: nil
            ),
            visualTheme: VisualTheme(backgroundColor: "#4A90E2", decorativeElements: []),
            location: nil,
            audioInstruction: nil,
            audioCompletion: nil,
            itemRule: nil,
            itemEmoji: nil
        )
    }

    func testStoryNumberParsedFromId() {
        let lab = makeLabyrinth(id: "denny_005_easy")
        XCTAssertEqual(lab.storyNumber, 5)
    }

    func testLevelNameParsedFromId() {
        let lab = makeLabyrinth(id: "denny_005_easy")
        XCTAssertEqual(lab.levelName, "easy")
    }

    func testStoryNumberFromVariousIds() {
        let lab1 = makeLabyrinth(id: "denny_001_easy")
        XCTAssertEqual(lab1.storyNumber, 1)

        let lab20 = makeLabyrinth(id: "denny_020_hard")
        XCTAssertEqual(lab20.storyNumber, 20)

        let lab10 = makeLabyrinth(id: "denny_010_medium")
        XCTAssertEqual(lab10.storyNumber, 10)
    }

    func testStoryNumberFromInvalidIdReturnsZero() {
        let lab = makeLabyrinth(id: "invalid")
        XCTAssertEqual(lab.storyNumber, 0)
    }

    func testLevelNameFromInvalidIdReturnsEmpty() {
        let lab = makeLabyrinth(id: "invalid")
        // Single component with no underscores should return empty
        XCTAssertEqual(lab.levelName, "")
    }

    func testLevelNameVariants() {
        let easy = makeLabyrinth(id: "denny_001_easy")
        XCTAssertEqual(easy.levelName, "easy")

        let medium = makeLabyrinth(id: "denny_010_medium")
        XCTAssertEqual(medium.levelName, "medium")

        let hard = makeLabyrinth(id: "denny_020_hard")
        XCTAssertEqual(hard.levelName, "hard")
    }
}
