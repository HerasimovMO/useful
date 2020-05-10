//
//  CalendarBar.swift
//  useful
//
//  Created by Mykhailo Herasimov on 2020-04-29.
//  Copyright © 2020 Mykhailo Herasimov. All rights reserved.
//

import UIKit

class CalendarBar: UIView {
    
    enum Week: Int, CaseIterable {
        case week1, week2, week3, week4, week5, week6
    }
    
    // Constants
    
    private let cornerRadius: CGFloat = 20
    
    private let indicatorHeight: CGFloat = 5
    private let indicatorWidth: CGFloat = 48
    private let indicatorInsets: UIEdgeInsets = .create(bottom: 8)
    
    private let legendBottomSpacing: CGFloat = 10
    private let daysGroupHeight: CGFloat = 32
    private let calendarInsets: UIEdgeInsets = .create(right: 12, bottom: 26, left: 12)
    private var numberOfCells: Int { return 7 * Week.allCases.count }
    private var calendarHeight: CGFloat { return daysGroupHeight * CGFloat(Week.allCases.count) }
    
    // -- Constants --
    
    // Views
    
    private lazy var collectionView: UICollectionView = {
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(CalendarItemCell.self)
        collectionView.backgroundColor = .clear
        return collectionView
    }()
    
    // -- Views --
    
    private var dataSource: UICollectionViewDiffableDataSource<Week, Int>! = nil
    private var selectedWeek: Week = .week3 {
        didSet {
            guard oldValue != selectedWeek else { return }
            var snapshot = dataSource.snapshot()
            snapshot.reloadSections([oldValue, selectedWeek])
            dataSource.apply(snapshot, animatingDifferences: true)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureUI() {
        
        backgroundColor = UIColor(collection: .primary)
        layer.cornerRadius = cornerRadius
        layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        translatesAutoresizingMaskIntoConstraints = false
        
        // -- Disclosure indicator --
        
        let disclosureIndicator = UIView()
        disclosureIndicator.backgroundColor = .white
        disclosureIndicator.translatesAutoresizingMaskIntoConstraints = false
        disclosureIndicator.layer.cornerRadius = indicatorHeight / 2
        
        addSubview(disclosureIndicator)
        NSLayoutConstraint.center(disclosureIndicator, in: self, for: [.horizontal])
        NSLayoutConstraint.snap(disclosureIndicator, to: self, for: [.bottom], sizeAttributes: [.height(value: indicatorHeight), .width(value: indicatorWidth)], with: indicatorInsets)
        
        // -- Calendar --
        
        configureHierarchy()
        configureDataSource()
        
        // -- Legend --
        
        let stackView = UIStackView.create(axis: .horizontal, spacing: 0, distribution: .fillEqually)
        addSubview(stackView)
        
        let legends = Calendar.current.veryShortWeekdaySymbols.map {
            UILabel.create(fontStyle: .subheadline, text: $0, textColor: .white, textAlignment: .center)
        }
        
        stackView.items = legends
        NSLayoutConstraint.snap(stackView, to: collectionView, for: [.left, .right])
        stackView.bottomAnchor.constraint(equalTo: collectionView.topAnchor, constant: -legendBottomSpacing).isActive = true
    }
}

extension CalendarBar {
    
    func createLayout() -> UICollectionViewLayout {
        
        let layout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            
            guard let self = self, let sectionType = Week(rawValue: sectionIndex) else { return nil }
            
            // --- Item ---
            
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            
            // --- Group ---
            
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .absolute(self.daysGroupHeight) )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 7)
            
            // --- Section ---
            
            let section = NSCollectionLayoutSection(group: group)
            
            // -- Background --
            
            if sectionType == self.selectedWeek {
                
                let weekBackgroundDecoration = NSCollectionLayoutDecorationItem.background(
                    elementKind: SupplementaryViewKind.background.kindIdentifier(WeekBackgroundDecorationView.self))
                section.decorationItems = [weekBackgroundDecoration]
            }
            
            return section
        }
        
        layout.register(
            WeekBackgroundDecorationView.self,
            forDecorationViewOfKind: SupplementaryViewKind.background.kindIdentifier(WeekBackgroundDecorationView.self))
        
        return layout
    }
}

extension CalendarBar {
    
    func configureHierarchy() {
        
        collectionView.delegate = self
        addSubview(collectionView)
        NSLayoutConstraint.snap(collectionView, to: self, for: [.left, .right, .bottom], sizeAttributes: [.height(value: calendarHeight)], with: calendarInsets)
    }
    
    func configureDataSource() {
        
        let calendarData = calculateCalendar()
        
        dataSource = UICollectionViewDiffableDataSource<Week, Int>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, index: Int) -> UICollectionViewCell? in
            
            let cell: CalendarItemCell = collectionView.dequeueReusableCell(for: indexPath)
            if let (days, currentMonth) = calendarData {
                cell.configure(day: days[index], isCurrentMonth: currentMonth.contains(index))
            }
            return cell
        }
        
        // Initial data
        var snapshot = NSDiffableDataSourceSnapshot<Week, Int>()
        
        let cells = Array(0..<numberOfCells).chunked(into: 7) // -- one month of days + remaining items
        Week.allCases.forEach {
            snapshot.appendSections([$0])
            snapshot.appendItems(cells[$0.rawValue])
        }
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    func calculateCalendar() -> (days: [Int], currentMonth: Range<Int>)? {
        
        let calendar = Calendar.current
        let currentDate = Date()
        
        if let firstDate = calendar.firstMonthDay(based: currentDate) {
            
            // Get the short name of the first day of the month. e.g. "Mon"
            let weekDay = firstDate.formatted(as: .custom(style: .day, timeZone: .current))
            
            // Calculate number of days in current month an the previous one;
            // Find week day for the 1st day of current month
            guard let currentMonthDaysCount = calendar.monthDays(from: firstDate),
                let weekDayIndex = calendar.shortWeekdaySymbols.firstIndex(of: weekDay),
                let previousMonth = calendar.previousMonth(from: firstDate),
                let previousMonthDaysCount = calendar.monthDays(from: previousMonth) else { return nil }
            
            // Offset in days for the 1st day of the month e.g. "Mon", "Tue", "Wed" -> "29", "30", "1"
            let weekDayOffset = calendar.shortWeekdaySymbols.prefix(upTo: Int(weekDayIndex)).indices.last ?? 0
            // Indexes for current month
            let currentMonthDays = Array(1...currentMonthDaysCount)
            
            // If 1th day is the first day of the week day
            if weekDayOffset == 0 {
                
                let remainingDays = Array(1...numberOfCells - currentMonthDaysCount)
                return (currentMonthDays + remainingDays, 0..<currentMonthDaysCount)
            } else {
                
                let previousMonthDays = Array((previousMonthDaysCount - weekDayOffset)...previousMonthDaysCount)
                let joinedDaysTotal = previousMonthDays.count + currentMonthDays.count
                let remainingDays = joinedDaysTotal < numberOfCells ? Array(1...(numberOfCells - joinedDaysTotal)) : []
                let offset = weekDayOffset + 1
                return (previousMonthDays + currentMonthDays + remainingDays, offset..<currentMonthDaysCount + offset)
            }
        }
        
        return nil
    }
}

extension CalendarBar: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let newSelectedWeek = Week(rawValue: indexPath.section) else { return }
        selectedWeek = newSelectedWeek
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
